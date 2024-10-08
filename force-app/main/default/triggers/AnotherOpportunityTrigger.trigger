/*
This Trigger has been reconfigured to be the only trigger for the Opportunity Object

A new instance of the OpportunityTriggerHandler is created, allowing access to all methods from that class and the parent class TriggerHandler.
All logic now exists outside of the trigger.
*/

trigger AnotherOpportunityTrigger on Opportunity (before insert, after insert, before update, after update, before delete, after delete, after undelete) {
    
    // Create a new instance of the OpportunityTriggerHandler class
    OpportunityTriggerHandler oppHandler = new OpportunityTriggerHandler(Trigger.new, Trigger.old, Trigger.newMap, Trigger.oldMap);

    // Call the run method from the parent TriggerHandler class
    oppHandler.run();

}