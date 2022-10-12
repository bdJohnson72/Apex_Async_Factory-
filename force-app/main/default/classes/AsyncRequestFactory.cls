/**
 *@author Brooks Johnson
 *@date 7/7/2020
 * @description A centralized class to handle all queueable apex. The user must create the appropriate value
 * in the Async_Request__c picklist, The class will use the picklist value in the Async Request record
 * and instantiate the appropriate class.
I */

public class AsyncRequestFactory implements Queueable, Database.AllowsCallouts {
    public class AsyncRequestFactoryException extends Exception {}
    @TestVisible
    private static Boolean throwError = false;


    public void execute(QueueableContext qc) {
        //TODO Add a counter to prevent infinite calls
        //TODO implement transaction finalizer

        List<Async_Request__c> asyncRequestList =  getRequests();
        if (asyncRequestList.size() == 0) {
            return;
        }
        Async_Request__c currentRequest = asyncRequestList[0];
        IAsyncRequest request = getInstanceOfAsyncRequest(currentRequest);
        try {
            request.processQueueable(currentRequest);
            delete currentRequest;
        } catch (DmlException dex) {
            // The next two catch blocks are meant to handle concurrency issues
            if (dex.getDmlType(0) == StatusCode.UNABLE_TO_LOCK_ROW || Test.isRunningTest()) {
                insert currentRequest.clone();
            }
        } catch (QueryException qex) {
            if (qex.getMessage().containsIgnoreCase('Record Currently Unavailable')) {
                insert currentRequest.clone();
            }
        } catch (Exception e) {
            currentRequest.Error__c = true;
            currentRequest.Stack_Trace__c = e.getMessage() + ' ' + e.getStackTraceString();
            currentRequest.Error_Type__c = e.getTypeName();
            update currentRequest;
        }

        checkQueue(asyncRequestList[0].Id);
    }

    /**
     * @param asyncRequest Request record at front of queue
     * This will be used to instantation the correct implementation of IAsyncRequest
     *
     * @return Object that is an instance of IAsyncRequest
     */
    private IAsyncRequest getInstanceOfAsyncRequest(Async_Request__c asyncRequest) {
        Type t = Type.forName(asyncRequest.Class_To_Instantiate__c);
        isValidClass(t);
        IAsyncRequest request = (IAsyncRequest) t.newInstance();
        return request;
    }

    private List<Async_Request__c> getRequests(){
        return [SELECT Id,
                Params__c,
                Class_To_Instantiate__c,
                JSON_Data__c
        FROM Async_Request__c
        WHERE Error__c = FALSE
        LIMIT 1
        FOR UPDATE];
    }

    private void checkQueue( Id currentRequestId){
        List<Async_Request__c> remainingRequests = [SELECT Id,
                Params__c,
                Class_To_Instantiate__c
                FROM Async_Request__c
        WHERE Id != :currentRequestId
        AND IsDeleted = FALSE
        AND Error__c = FALSE];

        //If we have have more records in the queue call another instance of the Async Request Factory
        if (!Test.isRunningTest() && remainingRequests.size() > 0
                && Limits.getLimitQueueableJobs() - Limits.getQueueableJobs() > 0) {
            AsyncRequestFactory requestFactory = new AsyncRequestFactory();
            System.enqueueJob(requestFactory);
        }
    }

    @TestVisible
    private IAsyncRequest isValidClass(Type t) {

       if (t.newInstance() instanceof IAsyncRequest){
           return (IAsyncRequest) t.newInstance();
       }else {
           throw new AsyncRequestFactoryException(t + ' is not a valid instance of IAsyncRequest');
       }
    }
}