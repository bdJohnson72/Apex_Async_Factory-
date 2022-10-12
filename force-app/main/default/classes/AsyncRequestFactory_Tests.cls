/**
 * Created by brooks.johnson on 10/4/2022.
 */

@IsTest
public class AsyncRequestFactory_Tests {
    @TestSetup
    private static void setUp() {
        //create an account for integration testing
        Account a = new Account(Name = 'test account');
        insert a;
    }

    @IsTest
    static void itShouldUpdateAccount() {
        //given
        Account account = [SELECT Id FROM Account LIMIT 1];
        Async_Request__c request = new Async_Request__c(Params__c = account.Id,
                Class_To_Instantiate__c = String.valueOf(AsyncRequestFactory_Tests.TestAsyncHandler.class));
        //when
        Test.startTest();
        insert request;
        Test.stopTest();
        Account updatedAccount = [SELECT Id, Name FROM Account LIMIT 1];
        //then
        System.assert(updatedAccount.Name == 'TEST ACCOUNT', 'The name should be all uppercase');
    }

    @IsTest
    static void itShouldThrowATypeException() {
        //Given
        Type t = AsyncRequestFactory_Tests.TestNonAsyncHandler.class;
        //when
        try {
            AsyncRequestFactory factory = new AsyncRequestFactory();
            factory.isValidClass(t);
            System.assert(true == false, 'We should never get here');
        } catch (Exception e) {
            //then
            System.assert(e instanceof AsyncRequestFactory.AsyncRequestFactoryException);
        }

    }

    @IsTest
    static void itShouldHandleDMLException(){
        //given
        Async_Request__c request = new Async_Request__c(Params__c = '1234',
                Class_To_Instantiate__c = String.valueOf(AsyncRequestFactory_Tests.DmlExceptionThrower.class));
        //when
        Test.startTest();
        insert request;
        Test.stopTest();

    }


    public class TestAsyncHandler implements IAsyncRequest {

        public void processQueueable(Async_Request__c asyncRequest) {
            System.debug('called with params ' + asyncRequest);
            updateAccountName(asyncRequest.Params__c);
        }

        private void updateAccountName(String accountId) {
            Account acc = [
                    SELECT Id, Name
                    FROM Account
                    WHERE Id = :accountId
            ];

            acc.Name.toUpperCase();
            update acc;
        }

    }
    /**
     * used to throw type exception
     */
    private class TestNonAsyncHandler {
    }

    public class DmlExceptionThrower implements IAsyncRequest{

        public void processQueueable(Async_Request__c asyncRequest) {
            System.debug('called processQueueable');
            throw new DmlException();
        }
    }

}