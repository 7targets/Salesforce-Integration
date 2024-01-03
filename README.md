# Salesforce-Integration
This Repository contains code required for integrating Salesforce with 7targets.

1. **LeadTriggerFor7Targets.tgr**
- In _Setup_ > _Object Manager_ > Search & click on _Lead_ > Go to _Triggers_ > Click on New button to create new Trigger using this code. 
- This code requires you to create two new fields in Lead object called _7Targets Assistant Email_ and _7Targets Sequence Name_. 

2. **SevenTargetsLeadIntegration.cls**
- This code allows you to assign Lead from Salesforce to SevenTargets Assistant which will followup on your behalf, as well as to stop followup to those leads.

For complete configuration process refer to these [help docs](https://7targets.ai/help/integrate/salesforce/)
