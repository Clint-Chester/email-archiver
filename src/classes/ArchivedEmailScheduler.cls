/* 
 * Author: Clint Chester
 * Version: 0.1
 * Description: Scheduler class to allow users to schedule how often they would like emails to be archived and 
 * based on the query critera in ArchivedEmailBatch class.
 * 
 */
global class ArchivedEmailScheduler implements Schedulable {
	global void execute(SchedulableContext ctx) {
        //Run the batch to archive the emails
        ArchivedEmailBatch emailBatch = new ArchivedEmailBatch();
        Id batchId = Database.executeBatch(emailBatch);
    }
}