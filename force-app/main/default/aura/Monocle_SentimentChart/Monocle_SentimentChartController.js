({
	afterScriptsLoaded : function(component, event, helper) 
    {
        helper.loadChart(component,event, helper);
        helper.getFeedbackResponse(component, event, helper);
	},
    
    doRefresh : function(component, event, helper)
    {
        if (component.get('v.feedbackResponse') != null)
        {
            helper.refreshResults(component, helper, null);
        }   
    }
})