/* 
 * Author: Clint Chester
 * Version: 0.1
 * Description: Email archiving services responsible for both archiving emails into the Big Object
 * and restoring the emails from the Big Object.
 * 
 */
public with sharing class ArchivedEmailService {
    /* 
     * Function to archive the email list by preparing the list to archive then inserting. 
     * Once inserted, the email messages can be deleted.
     * 
     * @param emails - A list of email messages to be archived
     * 
     */
    public void archiveEmails(List<EmailMessage> emails) {
        //Prepare the emails to archive by looping through the list to create the email archive list
        List<ArchivedEmail__b> archivedEmails = new List<ArchivedEmail__b>();
        for(EmailMessage e : emails) {
            ArchivedEmail__b a = new ArchivedEmail__b();
            a.ActivityId__c = e.ActivityId;
            a.BccAddress__c = e.BccAddress;
            a.BccIds__c = String.join(e.BccIds, ',');
            a.CcAddress__c = e.CcAddress;
            a.CcIds__c = String.join(e.CcIds, ',');
            a.ContentDocumentIds__c = String.join(e.ContentDocumentIds, ',');
            a.IsDeleted__c = String.valueOf(e.IsDeleted);
            a.FromAddress__c = e.FromAddress;
            a.FromName__c = e.FromName;
            a.HasAttachment__c = String.valueOf(e.HasAttachment);
            a.Headers__c = e.Headers;
            a.HtmlBody__c = e.HtmlBody;
            a.IsClientManaged__c = String.valueOf(e.IsClientManaged);
            a.IsExternallyVisible__c = String.valueOf(e.IsExternallyVisible);
            a.Incoming__c = String.valueOf(e.Incoming);
            a.MessageDate__c = e.MessageDate;
            a.MessageIdentifier__c = e.MessageIdentifier;
            a.ParentId__c = e.ParentId;
            a.RelatedToId__c = e.RelatedToId;
            a.ReplyToEmailMessageId__c = e.ReplyToEmailMessageId;
            a.Status__c = e.Status;
            a.Subject__c = e.Subject;
            a.TextBody__c = e.TextBody;
            a.ThreadIdentifier__c = e.ThreadIdentifier;
            a.ToAddress__c = e.ToAddress;
            a.ToIds__c = String.join(e.ToIds, ',');
            archivedEmails.add(a);
        }
        //Now perform the database operations, insert the archived emails and delete the normal emails
        SavePoint sp = Database.setSavePoint();
        try {
            //We need to make sure we don't accidentally insert test data into the big object
            if(!Test.isRunningTest()) {
            	Database.insertImmediate(archivedEmails);
            }
            Database.delete(emails);
        } catch (Exception e) {
            //Rollback and throw the exception
            Database.rollback(sp);
            throw e;
        }
    }

    /*
     * Function to restore an email that has been archived.
     * 
     * @param archivedEmail - The archived email from the Big Object that needs to be restored
     * 
     */
    public static void restoreEmail(ArchivedEmail__b archivedEmail) {
        //Instantiate the new email and its values.
        EmailMessage email = new EmailMessage();
        if(email.ParentId != null) {
            email.ActivityId = archivedEmail.ActivityId__c;
        }
		email.BccAddress = archivedEmail.BccAddress__c;
        email.CcAddress = archivedEmail.CcAddress__c;
        email.FromAddress = archivedEmail.FromAddress__c;
        email.FromName = archivedEmail.FromName__c;
        email.Headers = archivedEmail.Headers__c;
        email.HtmlBody = archivedEmail.HtmlBody__c;
        email.IsClientManaged = Boolean.valueOf(archivedEmail.IsClientManaged__c);
        email.Incoming = Boolean.valueOf(archivedEmail.Incoming__c);
        email.MessageDate = archivedEmail.MessageDate__c;
        email.MessageIdentifier = archivedEmail.MessageIdentifier__c;
        email.ParentId = archivedEmail.ParentId__c;
        email.RelatedToId = archivedEmail.RelatedToId__c;
        email.ReplyToEmailMessageId = archivedEmail.ReplyToEmailMessageId__c;
        email.Status = archivedEmail.Status__c;
        email.Subject = archivedEmail.Subject__c;
        email.TextBody = archivedEmail.TextBody__c;
        email.ThreadIdentifier = archivedEmail.ThreadIdentifier__c;
        email.ToAddress = archivedEmail.ToAddress__c;
        
        //Perform the database operations to insert the email record (so that the email ID can be used)
        SavePoint sp = Database.setSavePoint();
        try {
            Database.insert(email);
        } catch (Exception e) {
            //Rollback and throw the exception
            Database.rollback(sp);
            throw e;
        }
        
        //Now with an Email ID, setup the records to relate the email to contacts, leads and users
        List<EmailMessageRelation> emailRelations = new List<EmailMessageRelation>();
        if(String.isNotBlank(archivedEmail.BccIds__c)) {
            emailRelations.addAll(prepareEmailRelations(email.Id, (List<Id>)archivedEmail.BccIds__c.split(','), 'BccAddress'));
        }
        if(String.isNotBlank(archivedEmail.CcIds__c)) {
            emailRelations.addAll(prepareEmailRelations(email.Id, (List<Id>)archivedEmail.CcIds__c.split(','), 'CcAddress'));
        }
        if(String.isNotBlank(archivedEmail.ToIds__c)) {
            emailRelations.addAll(prepareEmailRelations(email.Id, (List<Id>)archivedEmail.ToIds__c.split(','), 'ToAddress'));
        }
        if(!emailRelations.isEmpty()) {
            sp = Database.setSavePoint();
            try {
                Database.insert(emailRelations);
            } catch (Exception e) {
                //Rollback and throw the exception
                Database.rollback(sp);
                throw e;
            }
        }
        
        //Now check if any content documents need to be related, then relate them
        if(String.isNotBlank(archivedEmail.ContentDocumentIds__c)) {
            List<ContentDocumentLink> contentLinks = new List<ContentDocumentLink>();
            for(Id contentId : (List<Id>)archivedEmail.ContentDocumentIds__c.split(',')) {
                ContentDocumentLink contentLink = new ContentDocumentLink();
                contentLink.ContentDocumentId = contentId;
                contentLink.LinkedEntityId = email.Id;
                contentLink.ShareType = 'V';
                contentLink.Visibility = 'AllUsers';
                contentLinks.add(contentLink);
            }
            //Now perform the database operations
            sp = Database.setSavePoint();
            try {
                Database.insert(contentLinks);
            } catch (Exception e) {
                //Rollback and throw the exception
                Database.rollback(sp);
                throw e;
            }
        }
    }
    
    /*
     * Function to create the email relations associated with an email.
     * 
     * @param emailId - The ID of the email to relate to.
     * @param relationIds - The IDs of the individuals to relate to the email.
     * @param relationType - Whether the individuals were from the ToAddress, CcAddress or BccAddress.
     * 
     */
    public static List<EmailMessageRelation> prepareEmailRelations(Id emailId, List<Id> relationIds, String relationType) {
        List<EmailMessageRelation> emailRelations = new List<EmailMessageRelation>();
        for(Id relationId : relationIds) {
            EmailMessageRelation er = new EmailMessageRelation();
            er.RelationType = relationType;
            er.EmailMessageId = emailId;
            er.RelationId = relationId;
            emailRelations.add(er);
        }
        return emailRelations;
    }
}
