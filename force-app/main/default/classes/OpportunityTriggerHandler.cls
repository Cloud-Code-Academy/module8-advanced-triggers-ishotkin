/*
 * OpportunityTriggerHandler extends the parent class TriggerHandler to specify actions for Opportunities.
 * 
 * Included methods:
 * 
 *  - beforeInsert: Sets a default Type for all Opportunities created without one
 *  - beforeUpdate: Validates if the Amount is under a certain threshhold, upends Stage changes to the Opportunity Description, and sets a Primary Contact if none is provided
 *  - beforeDelete: Validates that Opportunities are not Closed before deleting
 *                  *** IMPORTANT NOTE: If this method is changed, review requirements for not allowing deletion of Closed Opportunities for
 *                                      Accounts with Industry of "Banking" ***
 *  - afterInsert: Creates a Task for each new Opportunity
 *  - afterDelete: Alerts owner of the Oppotunity when it is deleted
 *  - afterUndelete: Reassigns undeleted Opportunities to a new Primary Contact
 * 
 * @author Ilana Shotkin
*/

public with sharing class OpportunityTriggerHandler extends TriggerHandler {

    // Class variables
    private List<Opportunity> newOppList;
    private List<Opportunity> oldOppList;
    private Map<Id, Opportunity> newOppMap;
    private Map<Id, Opportunity> oldOppMap;

    // Class Constructor
    public OpportunityTriggerHandler(List<Opportunity> newOppList, List<Opportunity> oldOppList, Map<Id, Opportunity> newOppMap, Map<Id, Opportunity> oldOppMap) {
        this.newOppList = newOppList;
        this.oldOppList = oldOppList;
        this.newOppMap = newOppMap;
        this.oldOppMap = oldOppMap;
    }
    
    /* Before Save methods */

    
    /* 
     * beforeInsert handler method:
     * 
     * Set a default Type of "New Customer" if no Type is provided upon creation
     */
    public override void beforeInsert() {
        // Set default Type for new Opportunities
        for (Opportunity opp : newOppList) {
            if (opp.Type == null){
                opp.Type = 'New Customer';
            }
        }  
    }

    /* 
     * beforeUpdate handler method:
     * 
     * Validate that the Amount is not under 5000. Upend Stage changes to the Desription. If the Primary Contact is not provided, 
     * set the Primcary COntact to the Opportunity's Account's CEO
     */
    public override void beforeUpdate() {
        // Create an empty map to store Contacts with their AccountId
        Map<Id, Contact> accountIdToContact = new Map<Id, Contact>();
        
        // When an opportunity is updated, validate that the amount is greater than 5000.
        for (Opportunity opp : newOppList){
            if(opp.Amount < 5000){
                opp.addError('Opportunity amount must be greater than 5000');

            } else {
                 // Only update the Opportunities than have a non-null StageName and whose StageName has changed
                if (opp.StageName != null && opp.StageName != oldOppMap.get(opp.Id).StageName){ 
                opp.Description = opp.Description + '\n Stage Change:' + opp.StageName + ':' + DateTime.now().format();
                }   
            }
        }

        // Get the Primary Contact for all Opportunities that are missing them
        Map<Id, Id> oppsWithPrimaryContact = OpportunityUtils.setPrimaryContact(newOppList, 'CEO');

        // Set the Primary Contact on triggered Opportunities that need one
        if (!oppsWithPrimaryContact.isEmpty()) {
            for (Opportunity opp : newOppList) {
                if (opp.Primary_Contact__c == null && oppsWithPrimaryContact.containsKey(opp.Id)){
                    opp.Primary_Contact__c = oppsWithPrimaryContact.get(opp.Id);
                }
            }
        }
    }

    /* 
     * beforeDelete handler method:
     * 
     * Validates that Opportunities are not closed prior to deletion, either "Closed Won" or "Closed Lost".
     * *** IMPORTANT NOTE: previous automation to prevent deletion of Closed Opportunities for Banking Accounts has been replaced by this method.
     *                      If this method is ever no longer needed, determine if Banking Accounts still need this validation. ***
     */
    public override void beforeDelete() {
        // Prevent deletion of closed Opportunities
        for (Opportunity updateOpp : oldOppList){
            if (updateOpp.IsClosed){
                updateOpp.addError('Cannot delete closed opportunity');
            }
        }
    }
    
    /* After Save Methods */

    /* 
     * afterInsert handler method:
     * 
     * For each new Opportunity, a follow-up Task must be created to call the Primary Contact.
     */
    public override void afterInsert() {    
        // Create an empty list to hold the new Tasks
        List<Task> newTasks = new List<Task>();
        
        // Create a new Task for each newly inserted Opportunity
        for (Opportunity opp : newOppList){
            Task tsk = new Task();
            tsk.Subject = 'Call Primary Contact';
            tsk.WhatId = opp.Id;
            tsk.WhoId = opp.Primary_Contact__c;
            tsk.OwnerId = opp.OwnerId;
            tsk.ActivityDate = Date.today().addDays(3);
            newTasks.add(tsk);
        }

        // Insert the new Tasks
        insert newTasks;
    }

    /* 
     * afterDelete handler method:
     * 
     * Sends an email notification to the owner of the Opportunity when it gets deleted.
     * Uses Salesforce's Messaging.SingleEmailMessage to send the email.
     */
    
    public override void afterDelete() {
        // Create empty list to hold the emails before sending
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();

        // Create each email and add to the list
        for (Opportunity opp : oldOppList){
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            String[] toAddresses = new String[]{};
            toAddresses.add(opp.Owner.Email);
            mail.setToAddresses(toAddresses);
            mail.setSubject('Opportunity Deleted : ' + opp.Name);
            mail.setPlainTextBody('Your Opportunity: ' + opp.Name +' has been deleted.');
            mails.add(mail);
        }        
        
        // Send the emails and collect any errors
        try {
            Messaging.sendEmail(mails);
        } catch (Exception e){
            System.debug('Exception: ' + e.getMessage());
        }
    }

   /* 
    * afterUndelete handler method:
    * 
    * Reassigns the Primary Contact on the Opportunities to the Account's "VP Sales" if 
    * they do not already have a Primary Contact.
    */
    public override void afterUndelete() {        
        // Create an empty list to hold the Opprotunities that will need to be updated
        List<Opportunity> updateOppList = new List<Opportunity>();
        // Retrieve a list of Opportunities with their updated Primary Contacts
        Map<Id,Id> oppMap = OpportunityUtils.setPrimaryContact(newOppList, 'VP Sales');
        
        // Populate the list of Opportunities to update using the retrieved Primcary Contacts
        for (Id oppId : oppMap.keySet()){
            Opportunity newOpp = new Opportunity(Id = oppId, Primary_Contact__c = oppMap.get(oppId));
            updateOppList.add(newOpp);
        }

        // Update the Opportunities
        update updateOppList;
    }
}