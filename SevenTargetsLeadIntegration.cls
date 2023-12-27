public class SevenTargetsLeadIntegration {
    
    private static final String API_ENDPOINT = 'https://api-qa.7targets.com/leads';
    private static final String TOKEN_ENDPOINT = 'https://login-qa.7targets.com/oauth2/token';

    private static String refreshToken() {
        Seven_Targets_API__c stc = [select Name, Seven_Targets_Client_Id__c, Seven_Targets_Client_Secret__c from seven_targets_api__c limit 1];

        String idSecretString = stc.Seven_Targets_Client_Id__c + ':' + stc.Seven_Targets_Client_Secret__c;
        String encodedIdSecretString = EncodingUtil.base64Encode(Blob.valueOf(idSecretString));

        HttpRequest tokenRequest = new HttpRequest();
        tokenRequest.setEndpoint(TOKEN_ENDPOINT);
        tokenRequest.setMethod('POST');
        tokenRequest.setHeader('Authorization', 'Basic ' + encodedIdSecretString);
        tokenRequest.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        tokenRequest.setBody('grant_type=client_credentials&scope=leads/post');

        Http tokenHttp = new Http();
        HttpResponse tokenResponse = tokenHttp.send(tokenRequest);
        String accessToken; 

        if (tokenResponse.getStatusCode() == 200) {
            accessToken = (String)((Map<String, Object>)JSON.deserializeUntyped(tokenResponse.getBody())).get('access_token');
        } else {
            System.debug('Error obtaining access token. Status code: ' + tokenResponse.getStatusCode());
            System.debug('Response body: ' + tokenResponse.getBody());
        }
        return accessToken;
    }

    private static void addNoteToLead(String leadId, String title, String body) {
        // Create a new Note record    
        Note newNote = new Note();
        newNote.ParentId = leadId; // The Lead Id
        newNote.Title = title; // Set the title for the note
        newNote.Body = body; // Set the content of the note

        insert newNote;
    }  

    @Future(callout=true)
    public static void AddLeadToSevenTargets(Id leadId) {
        
        Lead leadRecord = [SELECT Id, FirstName, Phone, Email, Title, LastName, LeadSource, Street, City, State, Country, Industry, Company, Status, sts_Assistant_Email__c, sts_Sequence_Name__c, sts_state__c FROM Lead WHERE Id = :leadId];
        
        Map<String, Object> leadDataMap = new Map<String, Object>();
        
        String location = '';
        if (leadRecord.Street != null) {
            location = location + leadRecord.Street + ', ';
        }
        if (leadRecord.City != null) {
            location = location + leadRecord.City +  ', ';
        }
        if (leadRecord.State != null) {
            location = location + leadRecord.State + ', ';
        }
        if (leadRecord.Country != null) {
            location = location + leadRecord.Country;
        }
        
        leadDataMap.put('name', leadRecord.FirstName);
        leadDataMap.put('lastName', leadRecord.LastName);
        leadDataMap.put('email', leadRecord.Email);
        leadDataMap.put('company', leadRecord.Company);
        leadDataMap.put('designation', leadRecord.Title);
        leadDataMap.put('industry', leadRecord.Industry);
        leadDataMap.put('location', location);
        leadDataMap.put('scheduleName', leadRecord.sts_Sequence_Name__c);
        leadDataMap.put('phoneno', leadRecord.Phone);
        leadDataMap.put('assistantEmail', leadRecord.sts_Assistant_Email__c);
        leadDataMap.put('source', leadRecord.LeadSource);
        leadDataMap.put('crm', 'SALESFORCE');
        leadDataMap.put('externalId', leadRecord.Id);
        leadDataMap.put('state', leadRecord.sts_state__c);

        // List<String> leadJsonList = new List<String>();
        // for (Lead leadRecord: leads){
        //    leadJsonList.add(JSON.serialize(leadRecord));
        // }
        
        // String leadsJsonArray = '[' + String.join(leadJsonList, ',') + ']';
        String accessToken = refreshToken();
        String bearerToken = 'Bearer '+ accessToken;
        HttpRequest request = new HttpRequest();
        request.setEndpoint(API_ENDPOINT);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Authorization', bearerToken);
        request.setHeader('7ts-user-identifier','936222e0-4098-4126-b7c7-feb8c159012f');
        request.setBody(JSON.serialize(leadDataMap));
        
        Http http = new Http();
        HttpResponse response = http.send(request);
        
        if (response.getStatusCode() == 200) {
            System.debug('Leads successfully sent to the 7Targets API.');
            String body = 'Thanks. I will start working on this lead. You can edit the message sequence or other details of this lead by clicking here: https://solution-qa.7targets.com/all-leads?id=' + leadRecord.Id;
            String title = 'Lead Added';
            addNoteToLead(leadRecord.Id, title, body);
        } else {
            System.debug('Error sending leads. Status code: ' + response.getStatusCode());
            String error_response = response.getBody();
            System.debug('Response body: ' + error_response);
            String body = 'Failed to Add Lead ' + error_response;
            String title = 'Failed To Add Lead';
            addNoteToLead(leadRecord.Id, title, body);
        }
    }
}