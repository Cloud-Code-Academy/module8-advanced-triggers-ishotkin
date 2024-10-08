/*
 * Additional methods needed for the OpportunityTriggerHandler class
 * 
 * @author Ilana Shotkin
*/

public with sharing class OpportunityUtils {
    /* 
     * Retrieve a List of all Contacts for Opportunities' Accounts with a specific Title
     * 
     * @param oppList The list of all Opportunities that need to have a Contact located
     * @param title The Title that the Contacts must have
     * @return A list of all Contacts fitting the criteria
     */
    public static List<Contact> getContactsByTitle(List<Opportunity> oppList, String title) {
        // Get contacts related to Opportunities with a certain title
        List <Contact> contactList = 
            [SELECT Id, FirstName, AccountId 
            FROM Contact 
            WHERE AccountId IN (SELECT AccountID FROM Opportunity WHERE Id IN :oppList) AND Title = :title 
            ORDER BY FirstName ASC];
        return contactList;
    }

    /* 
     * Set the Primary Contact on Opportunities that are missing it
     * 
     * @param contacts A list of Contacts to be used to set the Primary Contacts
     * @param oppList A list of Opportunities that may need a Primary Contact
     * @return A list of Opportunities with the correct Primary Contact
     */
    public static Map<Id, Id> setPrimaryContact(List<Opportunity> oppList, String title){
        // Create empty map to relate the Accounts to the Primary Contacts
        Map<Id, Id> accountIdToContact = new Map<Id, Id>();
        // Create empty map to relate Opportunities to the correct Primary Contact
        Map<Id, Id> oppToContact = new Map<Id, Id>();
        // Retrieve a list of Contacts for the Opportunities' Accounts with correct title
        List<Contact> contacts = getContactsByTitle(oppList, title);

        // Check if any contacts were found
        if (!contacts.isEmpty()) {
            // Add the Contacts and their Accounts to the map
            for (Contact cont : contacts) {
                if (!accountIdToContact.containsKey(cont.AccountId)) {
                    accountIdToContact.put(cont.AccountId, cont.Id);
                }
            }

            // For each Opportunity updated, if it does not have a Primary Contact, if its AccountId is in the map, use the related Contact from the map
            for (Opportunity opp : OppList){
                if (opp.Primary_Contact__c == null && accountIdToContact.containsKey(opp.AccountId)){
                    oppToContact.put(opp.Id, accountIdToContact.get(opp.AccountId));
                }
            }
        }

        // Return the list of Ids
        return oppToContact;
    }
}