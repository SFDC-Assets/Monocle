declare module "@salesforce/apex/Monocle_Helper.checkLiveFeedback" {
  export default function checkLiveFeedback(param: {recordId: any, utteranceText: any, speaker: any, objFeedback: any}): Promise<any>;
}
declare module "@salesforce/apex/Monocle_Helper.getFeedbackResponseScore" {
  export default function getFeedbackResponseScore(param: {recordId: any}): Promise<any>;
}
declare module "@salesforce/apex/Monocle_Helper.getFeedbackTemplate" {
  export default function getFeedbackTemplate(param: {recordId: any}): Promise<any>;
}
declare module "@salesforce/apex/Monocle_Helper.getSentimentFeedbackResponse" {
  export default function getSentimentFeedbackResponse(param: {recordId: any}): Promise<any>;
}
declare module "@salesforce/apex/Monocle_Helper.clearFeedbackItem" {
  export default function clearFeedbackItem(param: {recordId: any}): Promise<any>;
}
declare module "@salesforce/apex/Monocle_Helper.getVoiceCall" {
  export default function getVoiceCall(param: {recordId: any}): Promise<any>;
}
declare module "@salesforce/apex/Monocle_Helper.getChatTranscript" {
  export default function getChatTranscript(param: {recordId: any}): Promise<any>;
}
declare module "@salesforce/apex/Monocle_Helper.getSentimentChartData" {
  export default function getSentimentChartData(param: {feedbackResponseId: any}): Promise<any>;
}
