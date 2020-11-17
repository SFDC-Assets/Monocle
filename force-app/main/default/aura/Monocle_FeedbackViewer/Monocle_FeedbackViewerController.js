({
    doInit: function(component, event, helper) {
        //get feedback Template
        var action = component.get('c.getFeedbackTemplate'); 
        action.setParams({
            "recordId" : component.get('v.recordId') 
        });
        action.setCallback(this, function(a){
            var state = a.getState(); // get the response state
            if(state == 'SUCCESS' && a.getReturnValue() != null) {
                var theTemplate = a.getReturnValue();
                if (theTemplate != null)
                {
                    component.set('v.feedbackTemplate', theTemplate);
                    helper.runCustomFuntion(component,'','');
                    
                    //If recordId is Voice Call
                    if (component.get('v.recordId').startsWith('0LQ'))
                    {
                        //Get VoiceCall
                        helper.getVoiceCall(component, event, helper);
                        helper.subscribeToVoiceToolkit(component);
                    }
                    else if (component.get('v.recordId').startsWith('570'))
                    {
                        //Get VoiceCall
                        helper.getChatTranscript(component, event, helper);
                    }
                }
            }
        });
        $A.enqueueAction(action);
        
        
    },
    onDestroy: function(cmp, event, helper) {
        helper.unsubscribeFromVoiceToolkit(cmp);
    },
    // Chat Transcript Customer
    onChatTranscriptCustomer: function(cmp, evt, helper){
        helper.chatConversationEventListener(cmp, evt, 'Customer');        
    },
    
    // Chat Transcript Agent
    onChatTranscriptAgent: function(cmp, evt, helper){
        helper.chatConversationEventListener(cmp, evt,'Agent');
    },
    
    clearFeedback: function(component, event, helper)
    {
        var qResponseId = event.currentTarget.dataset.qresponseid;
        //alert(qResponseId);
        var action = component.get('c.clearFeedbackItem'); 
        action.setParams({
            "recordId" : qResponseId 
        });
        action.setCallback(this, function(a){
            var state = a.getState(); // get the response state
            if(state == 'SUCCESS') {
				//Refresh the Feedback Scoring
                helper.runCustomFuntion(component,'','');
            }
        });
        $A.enqueueAction(action);
        
    }
})