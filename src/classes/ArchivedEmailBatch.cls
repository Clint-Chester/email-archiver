/* 
 * Author: Clint Chester
 * Version: 0.1
 * Description: Batch class used to process large amounts of emails retrieved.
 * 
 */
global class ArchivedEmailBatch implements Database.Batchable<sObject> {
    ArchivedEmailService aes = new ArchivedEmailService();
    global Database.QueryLocator start(Database.BatchableContext bc) {
        //collect the batches of emails to be passed to execute
        return Database.getQueryLocator([SELECT Id, ActivityId, BccAddress, BccIds, CcAddress,
                                         CcIds, ContentDocumentIds, FromAddress, FromName, HasAttachment,
                                         Headers, HtmlBody, Incoming, IsClientManaged, IsDeleted,
                                         IsExternallyVisible, MessageDate, MessageIdentifier,
                                         ParentId, RelatedToId, ReplyToEmailMessageId, Status, Subject,
                                         ThreadIdentifier, TextBody, ToAddress, ToIds
                                         FROM EmailMessage
                                         WHERE MessageDate < :System.today().addYears(-1)]);
    }
    global void execute(Database.BatchableContext bc, List<EmailMessage> emails){
        aes.archiveEmails(emails);
    }    
    global void finish(Database.BatchableContext bc){
        // execute any post-processing operations
    }    
}