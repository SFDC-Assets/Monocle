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
        var recordId = cmp.get("v.recordId");
        //Confirm that the component is on a Voice Call Record page
        if (recordId.startsWith("0LQ")){
            this.runCustomFuntion(cmp, transcriptText, speaker);
        }
    },
    // Chat/Messaging Transcripts (Customer and Agent)
    chatConversationEventListener: function(cmp, evt, speaker) {
        var transcriptText = evt.getParam('content');
        var recordId = cmp.get("v.recordId");
        var chatRecordId = evt.getParam("recordId");       
        //Confirm that the Event came from the Chat that the component is on
        if (recordId.includes(chatRecordId)){
            this.runCustomFuntion(cmp, transcriptText, speaker);        
        }
    },
    
    // Example placeholder function invoked when a Voice or Chat/Message event is received
    runCustomFuntion: function(component, transcriptText, speaker)
    {
        var action = component.get('c.checkLiveFeedback'); 
        action.setParams({
            "recordId" : component.get('v.recordId'),
            "utteranceText" : transcriptText,
            "speaker" : speaker,
            "objFeedback" : component.get('v.feedbackTemplate')
        });
        action.setCallback(this, function(a){
            var state = a.getState(); // get the response state
            if(state == 'SUCCESS' && a.getReturnValue() != null) {
                //Only load the iteration once
                var qResponses = component.get('v.QuestionResponses');
                if (qResponses == null || qResponses.length == 0)
                {
                    component.set('v.QuestionResponses', a.getReturnValue());
                }
                else
                {
                    //Tell all the subcomponents to refresh
                    var appEvent = $A.get("e.c:Monocle_ItemRefresh");
                    appEvent.fire();
                }
                
                //Refresh sentiment component
                var sentimentComponent = component.find("sentimentComp")
                sentimentComponent.refreshResults();
                
                //Refresh Feedback Score
                this.refreshFeedbackResponseScore(component);
            }
        });
        $A.enqueueAction(action);
    },
    
    refreshFeedbackResponseScore: function(component)
    {
        var action = component.get('c.getFeedbackResponseScore'); 
        action.setParams({
            "recordId" : component.get('v.recordId')
        });
        action.setCallback(this, function(a){
            var state = a.getState(); // get the response state
            if(state == 'SUCCESS' && a.getReturnValue() != null) {
                component.set('v.feedbackResponseScore', a.getReturnValue());
            }
        });
        $A.enqueueAction(action);
    },
    
    getVoiceCall: function(component, event, helper)
    {
        var action = component.get('c.getVoiceCall'); 
        action.setParams({
            "recordId" : component.get('v.recordId')
        });
        action.setCallback(this, function(a){
            var state = a.getState(); // get the response state
            if(state == 'SUCCESS' && a.getReturnValue() != null) {
                component.set('v.voiceCall', a.getReturnValue());
                //alert(component.get('v.voiceCall').CallEndDateTime);
                if (component.get('v.voiceCall').CallEndDateTime == null)
                {
                    component.set('v.active', true);
                }
            }
        });
        $A.enqueueAction(action);
    },
    
    getChatTranscript: function(component, event, helper)
    {
        var action = component.get('c.getChatTranscript'); 
        action.setParams({
            "recordId" : component.get('v.recordId')
        });
        action.setCallback(this, function(a){
            var state = a.getState(); // get the response state
            if(state == 'SUCCESS' && a.getReturnValue() != null) {
                component.set('v.chatTranscript', a.getReturnValue());
                //alert(component.get('v.voiceCall').CallEndDateTime);
                if (component.get('v.chatTranscript').Status == 'InProgress')
                {
                    component.set('v.active', true);
                }
            }
        });
        $A.enqueueAction(action);
    },
    
})