/**
 * Created by brooks.johnson on 10/4/2022.
 */

trigger AsyncRequests on Async_Request__c (after insert, after update) {
   System.enqueueJob(new AsyncRequestFactory());

}