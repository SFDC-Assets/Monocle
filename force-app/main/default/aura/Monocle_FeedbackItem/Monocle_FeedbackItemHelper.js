({
	subscribeToVoiceToolkit: function(cmp) { 
        cmp._conversationEventListener = $A.getCallback(this.voiceConversationEventListener.bind(this, cmp));
        cmp.find('voiceToolkitApi').addConversationEventListener('TRANSCRIPT', cmp._conversationEventListener);
    },
    
    unsubscribeFromVoiceToolkit: function(cmp) {
        cmp.find('voiceToolkitApi').removeConversationEventListener('TRANSCRIPT', cmp._conversationEventListener);
    },
    // Voice Transcripts (Customer and Agent)
    voiceConversationEventListener: function(cmp, transcript) {
        var transcriptText = transcript.detail.content.text;
        var speaker = transcript.detail.sender.role;  
        this.runCustomFuntion(cmp, transcriptText, speaker);
    },
    // Chat/Messaging Transcripts (Customer and Agent)
    chatConversationEventListener: function(cmp, evt, speaker) {
        var transcriptText = evt.getParam('content');
        var recordId = cmp.get("v.recordId");
        this.runCustomFuntion(cmp, transcriptText, speaker);
    },
    
    // Example placeholder function invoked when a Voice or Chat/Message event is received
    loadfqresponse: function(component, event, helper)
    {
        var action = component.get('c.getFeedbackQuestionResponse'); 
        action.setParams({
            "recordId" : component.get('v.feedbackQRId')
        });
        action.setCallback(this, function(a){
            var state = a.getState(); // get the response state
            if(state == 'SUCCESS' && a.getReturnValue() != null) {
                var fqr = a.getReturnValue();                
                //SELECT Id, Name, Speaker__c, KeywordMatch__c, Question_Text__c, Completed__c, Utterance__c, Feedback_Question__r.RecordTypeId, Feedback_Question__r.Speaker__c, Feedback_Question__r.Intent_developer_name__c, Feedback_Question__r.Match_Phrase__c,  Feedback_Question__r.EntityType__c, Feedback_Question__r.ExtractionType__c
                component.set('v.inputTitle', fqr.Question_Text__c);
                component.set('v.completed', fqr.Completed__c);
                component.set('v.strValue', fqr.KeywordMatch__c);
                component.set('v.speaker', fqr.Speaker__c);
                component.set('v.helpText', fqr.Feedback_Question__r.HelpText__c);
                component.set('v.utterance', fqr.Utterance__c);
                
                component.set('v.oValueBool', fqr.Completed__c);
                component.set('v.oValueString', fqr.KeywordMatch__c);
                
                //if intent driven
                if (fqr.Feedback_Question__r.Intent_developer_name__c != null)
                {
                    component.set('v.matchType', 'Intent');
                    //component.set('v.inputType', 'checkbox');
                }
                
                ////Some entities
                //else if (fqr.Feedback_Question__r.EntityType__c.toLowerCase() == 'datetime')
                //{
                //    //Do the date
                //    component.set('v.inputType', 'datetime');
                //}
                else
                {
                    //Just basic Text
                    component.set('v.matchType', 'Keyword');
                    component.set('v.inputType', 'text');
                }
            }
        });
        $A.enqueueAction(action);
    },
    
    // Example placeholder function invoked when a Voice or Chat/Message event is received
    runCustomFuntion: function(component, transcriptText, speaker)
    {
        //Don't run if already completed
        if (component.get('v.completed') || !component.get('v.selfUpdate'))
        {
            return;
        }
        
        var action = component.get('c.checkFeedbackItem'); 
        action.setParams({
            "feedbackQResponseId" : component.get('v.feedbackQRId'),
            "utteranceText" : transcriptText,
            "speaker" : speaker,
            "matchType" : component.get('v.matchType'),
            "matchValue" : component.get('v.matchValue'),
            "speakerMatch" : component.get('v.speakerMatch'),
            "modelID" : component.get('v.modelID'),
            "tolerance" : component.get('v.tolerance')
        });
        action.setCallback(this, function(a){
            var state = a.getState(); // get the response state
            if(state == 'SUCCESS' && a.getReturnValue() != null) {
                var fqr = a.getReturnValue();
                component.set('v.completed', fqr.Completed__c);
                component.set('v.strValue', fqr.KeywordMatch__c);
                component.set('v.speaker', fqr.Speaker__c);
                component.set('v.utterance', fqr.Utterance__c);
                
                component.set('v.oValueBool', fqr.Completed__c);
                component.set('v.oValueString', fqr.KeywordMatch__c);
            }
        });
        $A.enqueueAction(action);
    },
    
    clearItem : function(component, event, helper)
    {
        component.set('v.completed', false);
        component.set('v.oValueBool', false);
        component.set('v.strValue', '');
        component.set('v.oValueString', '');
        component.set('v.speaker', '');
        component.set('v.utterance', '');
        
        if (component.get('v.feedbackQRId') != null)
        {
            var action = component.get('c.clearFeedbackItem'); 
            action.setParams({
                "recordId" : component.get('v.feedbackQRId') 
            });
            action.setCallback(this, function(a){
                var state = a.getState(); // get the response state
                if(state == 'SUCCESS') {
                    //Refresh the Feedback Scoring
                    this.loadfqresponse(component,event, helper);
                }
            });
            $A.enqueueAction(action);
        }
    },
    
    updateItem : function(component, event, helper)
    {
        component.set('v.completed', true);
        component.set('v.oValueBool', true);
        
        var theVal = component.get('v.strValue');
        component.set('v.oValueString', theVal);
        component.set('v.speaker', 'Agent');
        component.set('v.utterance', '(Manually updated by agent)');
        
        if (component.get('v.feedbackQRId') != null)
        {
            var action = component.get('c.updateFeedbackItem'); 
            action.setParams({
                "recordId" : component.get('v.feedbackQRId'),
                "completed" : component.get('v.completed'),
                "speaker" :  component.get('v.speaker'),
                "utterance" :  component.get('v.utterance'),
                "keyword" :  theVal
            });
            action.setCallback(this, function(a){
                var state = a.getState(); // get the response state
                if(state == 'SUCCESS') {
                    //Refresh the Feedback Scoring
                    this.loadfqresponse(component,event, helper);
                }
            });
            $A.enqueueAction(action);
        }
    },
    
    
})