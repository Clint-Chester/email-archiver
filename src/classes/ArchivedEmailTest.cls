/* 
 * Author: Clint Chester
 * Version: 0.1
 * Description: Test class for the batch email archiver.
 * 
 */
@isTest
private class ArchivedEmailTest {
    //Setup the test data to be used
    @testSetup static void setup() {
        //Create Accounts
        List<Account> accounts = new List<Account>();
        for(Integer i=0;i<10;i++) {
            accounts.add(new Account(name='Account '+i));
        }
        insert accounts;
        //Create Contacts linked to these Accounts
        List<Contact> contacts = new List<Contact>();
        for(Integer i=0;i<10;i++) {
            contacts.add(new Contact(FirstName='Julie', LastName='Jones', Email='test' + i + '@blahtest.com', AccountId=accounts.get(i).Id));
        }
        insert contacts;
        //Create Cases
        List<Case> cases = new List<Case>();
		for(Integer i=0;i<10;i++) {
            cases.add(new Case(AccountId=accounts.get(i).Id, ContactId=contacts.get(i).Id, Status='New', Origin='Email'));
        }
        insert cases;
        //Create Emails
        List<EmailMessage> emails = new List<EmailMessage>();
        for(Integer i=0;i<10;i++) {
            emails.add(new EmailMessage(Subject='Test Subject ' + i, Status='3', HtmlBody='<html><body><b>Hello</b></body></html>',
                                        FromName='Joan Jones ' + i, FromAddress='joanjones' + i + '@blahtest.com', RelatedToId=accounts.get(i).Id,
                                        MessageDate=System.today().addYears(-2)));
            emails.add(new EmailMessage(Subject='Subject Test ' + i, Status='3', HtmlBody='<html><body><b>Hello!</b></body></html>', ParentId=cases.get(i).Id,
                                        FromName='Jon Jones ' + i, FromAddress='jonjones' + i + '@blahtest.com', RelatedToId=cases.get(i).Id,
                                        MessageDate=System.today().addYears(-2)));
        }
        insert emails;
        //Create Email Relations
        List<EmailMessageRelation> emailRelations = new List<EmailMessageRelation>();
        for(Integer i=0;i<10;i++) {
            emailRelations.add(new EmailMessageRelation(RelationType='ToAddress', EmailMessageId=emails.get(i).Id, RelationId=contacts.get(i).Id));
        }
        insert emailRelations;
        //Prepare an email to archive and then restore
        EmailMessage emailToArchive = new EmailMessage(Subject='Email To Archive', Status='3', ParentId=cases.get(0).Id,
                                                       HtmlBody='<html><body><b>Hello</b></body></html>',
                                        			   FromName='Joan Jones', FromAddress='joanjones@blahtest.com', 
                                                       RelatedToId=cases.get(0).Id, MessageDate=System.today().addYears(-2));
        insert emailToArchive;
        List<EmailMessageRelation> emailRelationsToArchive = new List<EmailMessageRelation>();
        emailRelationsToArchive.add(new EmailMessageRelation(RelationType='ToAddress', EmailMessageId=emailToArchive.Id, RelationId=contacts.get(0).Id));
        emailRelationsToArchive.add(new EmailMessageRelation(RelationType='CcAddress', EmailMessageId=emailToArchive.Id, RelationId=contacts.get(1).Id));
        emailRelationsToArchive.add(new EmailMessageRelation(RelationType='BccAddress', EmailMessageId=emailToArchive.Id, RelationId=contacts.get(2).Id));
        insert emailRelationsToArchive;
        ContentVersion contentVersion = new ContentVersion(Title = 'Test', PathOnClient = 'Test.jpg', VersionData = Blob.valueOf('Test Content Data'), IsMajorVersion = true);
        insert contentVersion;
        ContentDocument contentDocument = [SELECT Id, LatestPublishedVersionId FROM ContentDocument WHERE LatestPublishedVersionId = :contentVersion.Id];
        ContentDocumentLink contentLink = new ContentDocumentLink(ContentDocumentId = contentDocument.Id, LinkedEntityId=emailToArchive.Id, ShareType = 'V', Visibility = 'AllUsers');
        insert contentLink;
    }
    
    //Test the batch archival of a list of emails. Currently the batch checks for emails with a MessageDate older than the current year.
    //TO DO: Mock the insertion of records into the Big Object to verify.
    @isTest static void archiveEmails() {
		//With the data setup, run the batch to archive the 20 emails
		Test.startTest();
        ArchivedEmailBatch emailBatch = new ArchivedEmailBatch();
        Id batchId = Database.executeBatch(emailBatch);
        Test.stopTest(); 
        //Confirm that the 20 emails have been deleted
        System.assertEquals(0, [SELECT Count() FROM EmailMessage]);
    }
    
    //Restore an email that is in the archived format
    @isTest static void restoreEmail() {
        //Prepare an archived email in the big object format
        //Get the email that was prepared for archival
        EmailMessage e = [SELECT Id, ActivityId, BccAddress, BccIds, CcAddress,
                          CcIds, ContentDocumentIds, FromAddress, FromName, HasAttachment,
                          Headers, HtmlBody, Incoming, IsClientManaged, IsDeleted,
                          IsExternallyVisible, MessageDate, MessageIdentifier,
                          ParentId, RelatedToId, ReplyToEmailMessageId, Status, Subject,
                          ThreadIdentifier, TextBody, ToAddress, ToIds
                          FROM EmailMessage
                          WHERE Subject = 'Email To Archive'];
        ArchivedEmail__b a = new ArchivedEmail__b(ActivityId__c = e.ActivityId, BccAddress__c = e.BccAddress,
                                                  BccIds__c = String.join(e.BccIds, ','), CcAddress__c = e.CcAddress,
                                                  CcIds__c = String.join(e.CcIds, ','), ContentDocumentIds__c = String.join(e.ContentDocumentIds, ','),
                                                  IsDeleted__c = String.valueOf(e.IsDeleted), FromAddress__c = e.FromAddress,
                                                  FromName__c = e.FromName, HasAttachment__c = String.valueOf(e.HasAttachment),
                                                  Headers__c = e.Headers, HtmlBody__c = e.HtmlBody, IsClientManaged__c = String.valueOf(e.IsClientManaged),
                                                  IsExternallyVisible__c = String.valueOf(e.IsExternallyVisible),
                                                  Incoming__c = String.valueOf(e.Incoming), MessageDate__c = e.MessageDate,
                                                  MessageIdentifier__c = e.MessageIdentifier, ParentId__c = e.ParentId,
                                                  RelatedToId__c = e.RelatedToId, ReplyToEmailMessageId__c = e.ReplyToEmailMessageId,
                                                  Status__c = e.Status, Subject__c = e.Subject, TextBody__c = e.TextBody,
                                                  ThreadIdentifier__c = e.ThreadIdentifier, ToAddress__c = e.ToAddress,
                                                  ToIds__c = String.join(e.ToIds, ','));
        
        //Now to test the restore function by deleting the email then restoring
        delete e;
        ArchivedEmailService.restoreEmail(a);
        
        //Now query the email to test that the email and all of the related records are restored
        EmailMessage restoredEmail = [SELECT Id, Subject FROM EmailMessage WHERE Subject='Email To Archive'];
        //There should be one email that has been restored
        System.assertEquals(1, [SELECT Count() FROM EmailMessage WHERE Subject='Email To Archive']);
        //There should be four EmailRelations (one each for FromAddress, ToAddress, CcAddress and BccAddress)
        System.assertEquals(4, [SELECT Count() FROM EmailMessageRelation WHERE EmailMessageId=:restoredEmail.Id]);
        //There should be one ContentDocumentLink
        System.assertEquals(1, [SELECT Count() FROM ContentDocumentLink WHERE LinkedEntityId=:restoredEmail.Id]);
    }
    
    //Test that the archiver is successfully scheduled
    @isTest static void scheduleEmailArchiver() {
        //Schedule the class to run on the first of each month
        String CRON_EXP = '0 0 1 1 * ? *';
		Test.startTest();
		String jobId = System.schedule('ArchivedEmailScheduler', CRON_EXP, new ArchivedEmailScheduler());
        
        //Get the information from the CronTrigger API object
        CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered, NextFireTime FROM CronTrigger WHERE id = :jobId];
        
        //Verify the expressions are the same
        System.assertEquals(CRON_EXP, ct.CronExpression);
        
        //Verify the job has not run
        System.assertEquals(0, ct.TimesTriggered);
        
        //Verify the next time the job will run (should be the first of the next month at 1am)
        System.assertEquals(DateTime.newInstance(Date.today().year(), Date.today().month() + 1, 1, 1, 0, 0), ct.NextFireTime);
        
        //Verify that the emails haven't been archived yet (21 emails are created in test setup)
        System.assertEquals(21, [SELECT Count() FROM EmailMessage]);  
        Test.stopTest();
    }
}