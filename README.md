# Email Archiver
A Salesforce prototype using a Big Object to archive and restore emails. There are still improvements to make, but provides a basic setup (including batching and scheduling) for archiving and restoring emails. Currently the MessageDate is the only indexed field for the Big Object and the batch class scheduled emails that have a message date greater than one year.

<h2>To Do List</h2>
<ul>
  <li>Create Lightning Component / Visualforce Component to display and restore emails from the Big Object</li>
  <li>Identify additional Big Object fields to index to manage record deletion accurately on restore (currently doesn't delete on restore)</li>
  <li>Provide user friendly interface to manage the archive schedule rules</li>
  <li>Update Apex Test Class to cover exceptions</li>
  <li>Update Apex Test Class to mock Big Object insertions</li>
</ul>
