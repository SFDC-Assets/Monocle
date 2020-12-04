public class Monocle_Helper 
{
    @AuraEnabled
    public static List<Feedback_Question_Response__c> checkLiveFeedback(String recordId, string utteranceText, string speaker, Feedback__c objFeedback)
    {
        if (speaker.toLowerCase() == 'enduser')
        {
            speaker = 'Customer';
        }
        system.debug('Calling Server Side: ' + recordId + ' ' + objFeedback);
        List<Feedback_Question_Response__c> responsequestions = getFeedbackQuestionResponses(recordId);
        FeedbackResponse__c feedbackSentimentResponse = getSentimentFeedbackResponse(recordId);
        
        Id intentRTId = Schema.SObjectType.FeedbackQuestion__c.getRecordTypeInfosByName().get('Intent Match').getRecordTypeId();
        Id keywordRTId = Schema.SObjectType.FeedbackQuestion__c.getRecordTypeInfosByName().get('Keyword Match').getRecordTypeId();
        Id nerRTId = Schema.SObjectType.FeedbackQuestion__c.getRecordTypeInfosByName().get('NER Match').getRecordTypeId();
        
        Boolean needIntents = false;
        Boolean needsNER = false;
        Boolean needsUpdate = false;
        
        //Loop through Response Questions
        for (Feedback_Question_Response__c response : responsequestions)
        {
            //See if you need an intent check
            if (!response.Completed__c && response.Feedback_Question__r.RecordTypeId == intentRTId)
            {
                needIntents = true;
            }
            //See if you need an NER check
            else if (!response.Completed__c && response.Feedback_Question__r.RecordTypeId == nerRTId)
            {
                needsNER = true;
            }
            
            //Check the keywords
            else if (!response.Completed__c && 
                     response.Feedback_Question__r.RecordTypeId == keywordRTId &&
                     (response.Feedback_Question__r.Speaker__c.toLowerCase() == speaker.toLowerCase() || response.Feedback_Question__r.Speaker__c == 'Agent or Customer')
                     )
            {
                String keywordMatch = checkKeywordMatch(utteranceText, response.Feedback_Question__r.Match_Phrase__c, response.Feedback_Question__r.ExtractionType__c);
                if (String.isNotBlank(keywordMatch))
                {
                    needsUpdate = true;
                    response.KeywordMatch__c = keywordMatch;
                    response.Completed__c = true;
                    response.Utterance__c = utteranceText;
                    response.Speaker__c = speaker;
                }
            }
        }
        
        //Process Intents
        if(needIntents && String.isNotBlank(utteranceText))
        {
            List<String> matches = CheckEinsteinIntentMatch(utteranceText, objFeedback.ModelID__c, objFeedback.IntentTolerance__c);
            for (String match : matches)
            {
                for (Feedback_Question_Response__c response : responsequestions)
                {
                    if (!response.Completed__c && 
                        response.Feedback_Question__r.RecordTypeId == intentRTId && 
                        match.toLowerCase() == response.Feedback_Question__r.Intent_developer_name__c.toLowerCase() &&
                        (response.Feedback_Question__r.Speaker__c.toLowerCase() == speaker.toLowerCase() || response.Feedback_Question__r.Speaker__c == 'Agent or Customer'))
                    {
                        response.Completed__c = true;
                        response.Utterance__c = utteranceText;
                        response.KeywordMatch__c = utteranceText;
                        response.Speaker__c = speaker;
                        needsUpdate = true;
                        break;
                    }
                }
            }
        }
        
        //Process NER
        if(needsNER && String.isNotBlank(utteranceText))
        {
            einsteinplay.Einstein_PredictionResult results = CheckEinsteinNER(utteranceText);
            for (einsteinplay.Einstein_Probability cI : results.probabilities)
            {
                for (Feedback_Question_Response__c response : responsequestions)
                {
                    if (!response.Completed__c && 
                        response.Feedback_Question__r.RecordTypeId == nerRTId && 
                        cI.probability * 100 >= objFeedback.IntentTolerance__c && 
                        response.Feedback_Question__r.EntityType__c.toLowerCase() == cI.label.toLowerCase() && 
                        (response.Feedback_Question__r.Speaker__c.toLowerCase() == speaker.toLowerCase() || response.Feedback_Question__r.Speaker__c == 'Agent or Customer'))
                    {
                        response.Completed__c = true;
                        response.Utterance__c = utteranceText;
                        response.Speaker__c = speaker;
                        response.KeywordMatch__c = cI.token;
                        needsUpdate = true;
                    }
                }
            }
        
        }
        
        if (feedbackSentimentResponse != null && feedbackSentimentResponse.EnableSentiment__c && String.isNotBlank(utteranceText))
        {
            //Add Sentiment
            CreateEinsteinSentiment(utteranceText, objFeedback.SentimentModelId__c , speaker, feedbackSentimentResponse.Id);
        }
        
        if (needsUpdate)
        {
            UPDATE responsequestions;
        }
        
        return responsequestions;
    }
    
    @AuraEnabled
    public static Feedback_Question_Response__c checkFeedbackItem(String feedbackQResponseId, string utteranceText, string speaker, string matchType, string matchValue, string speakerMatch, string modelID, Integer tolerance)
    {
        if (speaker.toLowerCase() == 'enduser')
        {
            speaker = 'Customer';
        }
        if (String.isBlank(utteranceText))
        {
            return null;
        }
        
        Feedback_Question_Response__c retVal = new Feedback_Question_Response__c();
        Boolean needsUpdate = false;
        
        if (String.isNotBlank(feedbackQResponseId))
        {
            Feedback_Question_Response__c responsequestion = [SELECT Id, Name, Speaker__c, KeywordMatch__c, Question_Text__c, Completed__c, Utterance__c, Feedback_Question__r.RecordTypeId, Feedback_Question__r.Speaker__c, Feedback_Question__r.Intent_developer_name__c, Feedback_Question__r.Match_Phrase__c,  Feedback_Question__r.EntityType__c, Feedback_Question__r.ExtractionType__c, Feedback_Question__r.Feedback__r.modelid__c, Feedback_Question__r.Feedback__r.IntentTolerance__c FROM Feedback_Question_Response__c WHERE ID=: feedbackQResponseId LIMIT 1];
            retVal = responsequestion;
            
            //Return if already completed
            if (retVal.Completed__c)
            {
                return retVal;
            }
            
            //Else Set the variables
            speakerMatch = retVal.Feedback_Question__r.Speaker__c;
            matchValue = retVal.Feedback_Question__r.Match_Phrase__c;
            modelID = retVal.Feedback_Question__r.Feedback__r.ModelID__c;
            tolerance = Integer.valueOf(retVal.Feedback_Question__r.Feedback__r.IntentTolerance__c);
            
            
            Id intentRTId = Schema.SObjectType.FeedbackQuestion__c.getRecordTypeInfosByName().get('Intent Match').getRecordTypeId();
            Id keywordRTId = Schema.SObjectType.FeedbackQuestion__c.getRecordTypeInfosByName().get('Keyword Match').getRecordTypeId();
            Id nerRTId = Schema.SObjectType.FeedbackQuestion__c.getRecordTypeInfosByName().get('NER Match').getRecordTypeId();
            
            if (retVal.Feedback_Question__r.RecordTypeId == intentRTId)
            {
                matchType = 'Intent';
                matchValue = retVal.Feedback_Question__r.Intent_developer_name__c;
            }
            else if (retVal.Feedback_Question__r.RecordTypeId == keywordRTId && retVal.Feedback_Question__r.ExtractionType__c == 'RegEx')
            {
                matchType = 'RegEx';
            }
            else if (retVal.Feedback_Question__r.RecordTypeId == keywordRTId)
            {
                matchType = 'Keyword';
            }
            else if (retVal.Feedback_Question__r.RecordTypeId == nerRTId)
            {
                matchType = 'Named Entity';
                matchValue = retVal.Feedback_Question__r.EntityType__c;
            }
        }
        
        //Check Keywords
        if ((matchType.toLowerCase() == 'keyword' || matchType.toLowerCase() == 'regex' ) && 
            (speaker.toLowerCase() == speakerMatch.toLowerCase() || speakerMatch.toLowerCase() == 'agent or customer')
           )
        {
            String keywordMatch = checkKeywordMatch(utteranceText, matchValue, matchType);
                if (String.isNotBlank(keywordMatch))
                {
                    needsUpdate = true;
                    retVal.KeywordMatch__c = keywordMatch;
                    retVal.Completed__c = true;
                    retVal.Utterance__c = utteranceText;
                    retVal.Speaker__c = speaker;
                }
        }
        
        //Check intents
        else if (matchType.toLowerCase() == 'intent' && 
                 (speaker.toLowerCase() == speakerMatch.toLowerCase() || speakerMatch.toLowerCase() == 'agent or customer')
                )
        {
            List<String> matches = CheckEinsteinIntentMatch(utteranceText, modelId, tolerance);
            for (String match : matches)
            {
                if (match.toLowerCase() == matchValue.toLowerCase())
                {
                    retVal.Completed__c = true;
                    retVal.Utterance__c = utteranceText;
                    retVal.KeywordMatch__c = utteranceText;
                    retVal.Speaker__c = speaker;
                    needsUpdate = true;
                }
            }
        }
        
        //Check NER
        else if (matchType.toLowerCase() == 'named entity' && 
                 (speaker.toLowerCase() == speakerMatch.toLowerCase() || speakerMatch.toLowerCase() == 'agent or customer')
                )
        {
            einsteinplay.Einstein_PredictionResult results = CheckEinsteinNER(utteranceText);
            for (einsteinplay.Einstein_Probability cI : results.probabilities)
            {
                if (cI.probability * 100 >= tolerance && 
                    matchValue.toLowerCase() == cI.label.toLowerCase()
                   )
                {
                    retVal.Completed__c = true;
                    retVal.Utterance__c = utteranceText;
                    retVal.Speaker__c = speaker;
                    retVal.KeywordMatch__c = cI.token;
                    needsUpdate = true;
                }
            }
        }
        
        if (needsUpdate && String.isNotBlank(feedbackQResponseId))
        {
            UPDATE retVal;
        }
        
        return retVal;
    }
    
    private static List<Feedback_Question_Response__c> getFeedbackQuestionResponses(string recordId)
    {
        List<Feedback_Question_Response__c> responsequestions;
        
        if (recordId.startsWith('0LQ'))
        {
            responsequestions = new List<Feedback_Question_Response__c>([SELECT Id, Name, Speaker__c, KeywordMatch__c, Question_Text__c, Completed__c, Utterance__c, Feedback_Question__r.RecordTypeId, Feedback_Question__r.Speaker__c, Feedback_Question__r.Intent_developer_name__c, Feedback_Question__r.Match_Phrase__c,  Feedback_Question__r.EntityType__c, Feedback_Question__r.ExtractionType__c FROM Feedback_Question_Response__c WHERE Feedback_Response__r.VoiceCall__c =: recordId ORDER BY Feedback_Question__r.Order__c ASC]);
        }
        else if (recordId.startsWith('570'))
        {
            responsequestions = new List<Feedback_Question_Response__c>([SELECT Id, Name, Speaker__c, KeywordMatch__c, Question_Text__c, Completed__c, Utterance__c, Feedback_Question__r.RecordTypeId, Feedback_Question__r.Speaker__c, Feedback_Question__r.Intent_developer_name__c, Feedback_Question__r.Match_Phrase__c,  Feedback_Question__r.EntityType__c, Feedback_Question__r.ExtractionType__c FROM Feedback_Question_Response__c WHERE Feedback_Response__r.ChatTranscript__c =: recordId ORDER BY Feedback_Question__r.Order__c ASC]);
        }
        return responsequestions;
    }
    
    @AuraEnabled
    public static Feedback_Question_Response__c getFeedbackQuestionResponse(string recordId)
    {
        List<Feedback_Question_Response__c> responsequestions = new List<Feedback_Question_Response__c>([SELECT Id, Name, Speaker__c, KeywordMatch__c, Question_Text__c, Completed__c, Utterance__c, Feedback_Question__r.HelpText__c, Feedback_Question__r.RecordTypeId, Feedback_Question__r.Speaker__c, Feedback_Question__r.Intent_developer_name__c, Feedback_Question__r.Match_Phrase__c,  Feedback_Question__r.EntityType__c, Feedback_Question__r.ExtractionType__c FROM Feedback_Question_Response__c WHERE Id =: recordId LIMIT 1]);
        if (responsequestions.size() > 0)
        {
            return responsequestions[0];
        }
        return null;
    }
    
    @AuraEnabled
    Public static Integer getFeedbackResponseScore(string recordId)
    {
        Integer responseScore = 100;
        Integer completed = 0;
        List<Feedback_Question_Response__c> responsequestions = getFeedbackQuestionResponses(recordId);
        for (Feedback_Question_Response__c r : responsequestions)
        {
            if(r.completed__c)completed++;
        }
        if (responsequestions.size() > 0)
        {
            responseScore = Integer.valueof(Decimal.valueOf(completed)/Decimal.valueOf(responsequestions.size()) * 100);
            
            //CHANGE TO WORK WITH Progress Ring
            Decimal s = Decimal.valueOf(responseScore) / 10;
            s = s.round(System.RoundingMode.HALF_UP) * 10;
            return Integer.valueOf(s);
            // END CHANGE
        }
        return responseScore;
    }
    
    private static string checkKeywordMatch(string utteranceText, string keywordString, string extractionType)
    {
        //See if regex is set
        if (extractionType == 'RegEx')
        {
            try
            {
                Matcher m = Pattern.compile(keywordString).matcher(utteranceText);
                //system.debug('Attempting to do regex:' + keywordString + ' to ' + utteranceText);
                while (m.find()) 
                {
                    //system.debug('Found: '+ m.group());
                    return m.group();
                }
            }
            catch(exception ex)
            {
                system.debug('Error:' + ex.getMessage());
            }
        }
        else //value match
        {
            //Iterate through Pipe List
            for (string matchString : keywordString.split('\\|'))
            {
                if (utteranceText.toLowerCase().contains(matchString.toLowerCase()))
                {
                    return matchString;
                }
                else if (keywordString.toLowerCase() == '{!agentname}' && utteranceText.toLowerCase().contains(UserInfo.getFirstName().toLowerCase()))
                {
                    return UserInfo.getFirstName();
                }
            }
        }
        return null;
    }
    
    @AuraEnabled
    public static Feedback__c getFeedbackTemplate(String recordId)
    {
        //Get Feedback Response
        List<FeedbackResponse__c> fr;
        if (recordId.startsWith('0LQ'))
        {
            fr = new List<FeedbackResponse__c>([SELECT Feedback__c FROM FeedbackResponse__c WHERE VoiceCall__c =: recordId LIMIT 1]);
        }
        else if (recordId.startsWith('570'))
        {
            fr = new List<FeedbackResponse__c>([SELECT Feedback__c FROM FeedbackResponse__c WHERE ChatTranscript__c  =: recordId LIMIT 1]);
        }
        
        if (fr.size() == 1)
        {
            return [SELECT Id,ModelID__c,IntentTolerance__c,EnableSentiment__c, SentimentModelId__c   FROM Feedback__c WHERE Id =: fr[0].Feedback__c];
        }
        return null;
    }
    
    @AuraEnabled
    public static FeedbackResponse__c getSentimentFeedbackResponse(String recordId)
    {
        //Get Feedback Response
        List<FeedbackResponse__c> fr;
        if (recordId.startsWith('0LQ'))
        {
            fr = new List<FeedbackResponse__c>([SELECT Feedback__c, EnableSentiment__c  FROM FeedbackResponse__c WHERE VoiceCall__c =: recordId AND EnableSentiment__c = true LIMIT 1]);
        }
        else if (recordId.startsWith('570'))
        {
            fr = new List<FeedbackResponse__c>([SELECT Feedback__c, EnableSentiment__c  FROM FeedbackResponse__c WHERE ChatTranscript__c  =: recordId AND EnableSentiment__c = true LIMIT 1]);
        }
        
        if (fr.size() == 1)
        {
            return fr[0];
        }
        return null;
    }
    
    @AuraEnabled
    public static void clearFeedbackItem(String recordId)
    {
        Feedback_Question_Response__c  fqr = [SELECT Completed__c, Utterance__c FROM Feedback_Question_Response__c  WHERE ID=: recordId];
        fqr.completed__c = false;
        fqr.Utterance__c = '';
        fqr.Speaker__c = null;
        fqr.KeywordMatch__c = '';
        UPDATE fqr;
    }
    
    @AuraEnabled
    public static void updateFeedbackItem(String recordId, Boolean completed, String speaker, String utterance, String keyword)
    {
        Feedback_Question_Response__c  fqr = [SELECT Completed__c, Utterance__c FROM Feedback_Question_Response__c  WHERE ID=: recordId];
        fqr.completed__c = completed;
        fqr.Utterance__c = utterance;
        fqr.Speaker__c = speaker;
        fqr.KeywordMatch__c = keyword;
        UPDATE fqr;
    }
    
    @AuraEnabled
    public static VoiceCall getVoiceCall(String recordId)
    {
        VoiceCall  vc = [SELECT Id, CallEndDateTime,CallDisposition,CallAcceptDateTime  FROM VoiceCall  WHERE ID=: recordId];
        return vc;
    }
    
    @AuraEnabled
    public static LiveChatTranscript getChatTranscript(String recordId)
    {
        LiveChatTranscript  obj = [SELECT Id, Status  FROM LiveChatTranscript  WHERE ID=: recordId];
        return obj;
    }
    
    @AuraEnabled
    public static SentimentChartData getSentimentChartData(String feedbackResponseId)
    {
        List<FeedbackSentimentResponse__c> objFSRs = new List<FeedbackSentimentResponse__c>([SELECT Id, Value__c, Speaker__c, Probability__c, ElapsedTime__c FROM FeedbackSentimentResponse__c WHERE Feedback_Response__c =: feedbackResponseId ORDER BY CreatedDate ASC]);
        List<Integer> cSentiment = new List<Integer>();
        List<Integer> aSentiment = new List<Integer>();
        List<String> labels = new List<String>();
        labels.add('0min 0sec');
        cSentiment.add(0);
        aSentiment.add(0);
        
        for (FeedbackSentimentResponse__c resp : objFSRs)
        {
            labels.add(resp.ElapsedTime__c );
            
            integer theValue = 0;
            if (resp.Value__c == 'Positive') theValue = 1;
            else if (resp.Value__c == 'Negative') theValue = -1;
            
            if (resp.Speaker__c == 'Agent')
            {
                cSentiment.add(cSentiment[cSentiment.size()-1]);
                aSentiment.add(aSentiment[aSentiment.size()-1] + theValue);
            }
            else
            {
                cSentiment.add(cSentiment[cSentiment.size()-1] + theValue);
                aSentiment.add(aSentiment[aSentiment.size()-1]);
            }
        }
        
        SentimentChartData retVal = new SentimentChartData();
        retVal.labels = labels;
        retVal.cdata = cSentiment;
        retVal.adata = aSentiment;
        return retVal;
    }
    
    public static List<String> CheckEinsteinIntentMatch(string utteranceText, string modelID, decimal tolerance)
    {
        List<String> results = new List<String>();
        einsteinplay.Einstein_PredictionService serviceIntent = new einsteinplay.Einstein_PredictionService(einsteinplay.Einstein_PredictionService.Types.INTENT);
        einsteinplay.Einstein_PredictionResult predictionIntent = serviceIntent.predictIntent(modelID, utteranceText, 5, '');
        
        for (einsteinplay.Einstein_Probability cI : predictionIntent.probabilities)
        {
            system.debug('prob:' + cI.probability + ' tol:' + tolerance);
            If (cI.probability * 100 >= tolerance)
            {
                results.add(cI.label);
            }
        }
        return results;
    }
    
    public static einsteinplay.Einstein_PredictionResult CheckEinsteinNER(string utteranceText)
    {
        einsteinplay.Einstein_PredictionService serviceNER = new einsteinplay.Einstein_PredictionService(einsteinplay.Einstein_PredictionService.Types.NER);
        einsteinplay.Einstein_PredictionResult predictionNER = serviceNER.predictNER('ENTITIES', utteranceText, 5, '');
        return predictionNER;
    }
    
    public static void CreateEinsteinSentiment(string utteranceText, string modelID, string speaker, Id feedbackResponseId)
    {
        einsteinplay.Einstein_PredictionService serviceSentiment = new einsteinplay.Einstein_PredictionService(einsteinplay.Einstein_PredictionService.Types.SENTIMENT);
        einsteinplay.Einstein_PredictionResult predictionSentiment = serviceSentiment.predictSentiment(modelID, utteranceText, 3, '');
        
        FeedbackSentimentResponse__c newSentiment = new FeedbackSentimentResponse__c();
        newSentiment.Value__c = predictionSentiment.probabilities[0].label;
        newSentiment.Probability__c = integer.valueOf(100 * predictionSentiment.probabilities[0].probability);
        newSentiment.Speaker__c = speaker;
        newSentiment.Feedback_Response__c = feedbackResponseId;
        INSERT newSentiment;
    }
    
    
    public class SentimentChartData
    {
        @AuraEnabled
        public List<string> labels {get;set;}
        @AuraEnabled
        public List<Integer> adata {get;set;}
        @AuraEnabled
        public List<Integer> cdata {get;set;}
    }
}