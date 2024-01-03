public class SevenTargetsLeadIntegration {
    
    private static final String API_ENDPOINT = 'https://api.7targets.com/leads';
    private static final String TOKEN_ENDPOINT = 'https://login.7targets.com/oauth2/token';
    private static final String APP_LEAD_URL = 'https://solution.7targets.com/all-leads?id=';

    private static String refreshToken() {
        Seven_Targets_API_Auth__mdt stc = [select Seven_Targets_Client_Id__c, Seven_Targets_Client_Secret__c from Seven_Targets_API_Auth__mdt limit 1];

        
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
    public static void salesforceToSevenTargets(Id leadId) {

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
        leadDataMap.put('crm', 'SALESFORCE');
        leadDataMap.put('externalId', leadRecord.Id);

        String accessToken = refreshToken();
        if(String.isNotBlank(accessToken)){
            String bearerToken = 'Bearer '+ accessToken;
            HttpRequest request = new HttpRequest();

            Seven_Targets_API_Auth__mdt st_uid = [select Seven_Targets_User_ID__c from Seven_Targets_API_Auth__mdt limit 1];
            request.setHeader('Content-Type', 'application/json');
            request.setHeader('Authorization', bearerToken);
            request.setHeader('7ts-user-identifier', st_uid.Seven_Targets_User_ID__c);
            request.setBody(JSON.serialize(leadDataMap));
            Http http = new Http();

            if(String.isBlank(leadRecord.sts_Assistant_Email__c)){
                request.setMethod('PUT');
                request.setEndpoint(API_ENDPOINT + '/stop/followup');
                HttpResponse response = http.send(request);
                if (response.getStatusCode() == 200) {
                    System.debug('Stopped Followup successfully for Lead ' + String.valueOf(leadRecord.Id));
                    Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(response.getBody());
                    Integer sts_leadId = (Integer)responseMap.get('id');
                    String leadIdString = String.valueOf(sts_leadId);
                    String body = 'Stopped Lead Followup. You can view details of this lead by clicking here: ' + APP_LEAD_URL + leadIdString;
                    String title = 'Stopped Followup in 7Targets';
                    addNoteToLead(leadRecord.Id, title, body);
                } else {
                    System.debug('Error Stopping lead Followup in 7Targets. Status code: ' + response.getStatusCode());
                    String error_response = response.getBody();
                    System.debug('Response body: ' + error_response);
                    String body = 'Failed to Stop Followup in 7Targets :' + error_response;
                    String title = 'Failed to Stop Followup in 7Targets';
                    addNoteToLead(leadRecord.Id, title, body);
                }
            }
            else {
                request.setMethod('POST');
                request.setEndpoint(API_ENDPOINT);
                HttpResponse response = http.send(request);
                if (response.getStatusCode() == 201) {
                    System.debug('Leads successfully Added to the 7Targets.');
                    Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(response.getBody());
                    Integer sts_leadId = (Integer)responseMap.get('id');
                    String leadIdString = String.valueOf(sts_leadId);
                    String body = 'Thanks. I will start working on this lead. You can edit the message sequence or other details of this lead by clicking here: ' + APP_LEAD_URL + leadIdString;
                    String title = 'Lead Created in 7Targets';
                    addNoteToLead(leadRecord.Id, title, body);
                    String lead_state = (String)responseMap.get('sts_state__c');
                    leadRecord.sts_state__c = lead_state;
                    update leadRecord; // Only updating State to make sure it doesn't go in infinite loop
                } else {
                    System.debug('Error Creating lead in 7Targets. Status code: ' + response.getStatusCode());
                    String error_response = response.getBody();
                    System.debug('Response body: ' + error_response);
                    String body = 'Failed to Add Lead in 7Targets : ' + error_response;
                    String title = 'Failed To Add Lead in 7Targets';
                    addNoteToLead(leadRecord.Id, title, body);
                }
            }
        } else {
            addNoteToLead(leadRecord.Id,'Authorization Failure','Unable to authorize with 7Targets API. Please Connect with 7Targets Support.');
        }
    }
}