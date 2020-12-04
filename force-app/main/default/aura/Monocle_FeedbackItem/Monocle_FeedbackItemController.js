({
	doInit : function(component, event, helper) 
    {
        if (component.get('v.selfUpdate'))
        {
            helper.subscribeToVoiceToolkit(component);
        }
        
        if (component.get('v.feedbackQRId') != null)
        {
            //Load the FeedbackQuestionResponse
            helper.loadfqresponse(component, event, helper);
        }
        else //we need to configure this manually
        {
            //init all the values
            if (component.get('v.matchType').toLowerCase() == 'intent')
            {
                //component.set('v.inputType', 'checkbox');
            }
            //else if (component.get('v.matchType').toLowerCase() == 'named entity' &&
            //        component.get('v.matchValue').toLowerCase() == 'datetime')
            //{
            //    component.set('v.inputType', 'datetime');
            //}
        }
	},
    
    doRefresh : function(component, event, helper) 
    {
        helper.loadfqresponse(component, event, helper);
    },
    
    // Chat Transcript Customer
    onChatTranscriptCustomer: function(cmp, evt, helper){
        if (cmp.get('v.selfUpdate'))
        {
            helper.chatConversationEventListener(cmp, evt, 'Customer');
        }
    },
    
    // Chat Transcript Agent
    onChatTranscriptAgent: function(cmp, evt, helper){
        if (cmp.get('v.selfUpdate'))
        {
            helper.chatConversationEventListener(cmp, evt, 'Agent');
        }
    },
    
    onDestroy: function(cmp, event, helper) {
        if (cmp.get('v.selfUpdate'))
        {
            helper.unsubscribeFromVoiceToolkit(cmp);
        }
    },
    
    checkChange : function(component, event, helper)
    {
        if (component.get('v.matchType').toLowerCase() == 'intent')
        {
            //return;
        }
        
        var newVal = component.get('v.strValue');
        if (newVal == null || newVal == '')
        {
            helper.clearItem(component, event, helper);
        }
        else
        {
            //Update the item
            helper.updateItem(component, event, helper);
        }
        
    },
    
    toggleChange : function(component, event, helper)
    {
        if (component.get('v.matchType').toLowerCase() != 'intent')
        {
            return;
        }
        
        if(!component.get('v.completed'))
        {
            helper.clearItem(component, event, helper);
        }
        else
        {
            //Update the item
            helper.updateItem(component, event, helper);
        }
        
    },
    
    clearField : function(component, event, helper)
    {
        helper.clearItem(component, event, helper);
    },
    
    setField : function(component, event, helper)
    {
        component.set('v.completed', true);
        component.set('v.oValueBool', true);
        component.set('v.strValue', 'MARKED COMPLETE');
        component.set('v.oValueString', 'MARKED COMPLETE');
        component.set('v.speaker', 'Agent');
        component.set('v.utterance', 'MARKED COMPLETE');
        helper.updateItem(component, event, helper);
    },
})