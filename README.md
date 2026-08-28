# Credit Card Analyzer Agent
This folder contains the Agentforce Agent Script authoring bundle for the**Credit Card Analyzer** employee agent.
Agent Script defines the agent's instructions, routing, variables, and actioncontracts. The actual work is performed by Salesforce Knowledge, a PromptTemplate, Salesforce's standard record-update action, a Flow, and Apex.
## Bundle Files
| File | Purpose || --- | --- || `Credit_Card_Analyzer_1.agent` | Agent Script source: configuration, variables, routing, subagents, instructions, and action definitions. || `Credit_Card_Analyzer_1.bundle-meta.xml` | Salesforce `AiAuthoringBundle` metadata. It identifies this bundle as an agent and targets `Credit_Card_Analyzer.v1`. || `README.md` | This documentation. It is not part of the Agentforce runtime. |
The project package directory is `force-app`, as defined in the root`sfdx-project.json`.
## What the Agent Does
In general terms, the agent behaves like a group of virtual Salesforcespecialists:
1. The router interprets the employee's request.2. It sends the request to the most appropriate subagent.3. The subagent answers using instructions and, when appropriate, a   Salesforce action.4. For approval or rejection, the agent can update the current Account and   perform a follow-up action.
Supported request categories are:
- Company policies, products, procedures, and troubleshooting questions- Account summary and credit-card application review- Credit-card application approval- Credit-card application rejection- Requests that are off-topic or too ambiguous to process
## Topic and Routing Map
Every conversation starts at `agent_router`.
```mermaidflowchart TD    U[Employee request] --> R[agent_router]    R --> F[GeneralFAQ]    R --> O[off_topic]    R --> A[ambiguous_question]    R --> C[Credit_Card_Approver]    F --> K[AnswerQuestionsWithKnowledge]    C --> S[Account_Summarize]    C --> V[UpdateRecordFields]    C --> P[Show_Offer]    C --> E[Send_email]    K --> KA[Salesforce Knowledge search]    S --> PT[Account_Summary Prompt Template]    V --> CRM[Update current Account]    P --> AP[Apex OfferController]    E --> FL[Send_Decision_Email Flow]```
The router uses the `@utils.transition` utility. A transition is a one-wayhandoff to another subagent; the router does not continue processing afterthe handoff.
## Business Decision Flow
The approval and rejection paths collect different information beforechanging the Account status.
```mermaidflowchart TD   S[Credit_Card_Approver] --> D{Employee decision}   D -->|Approve| L[Collect assigned credit limit]   L --> T[Collect interest rate tier]   T --> AC[Set status to Approved]   AC --> AU[Confirm and update Account CC_Status__c]   AU --> AO[Set showoffer to True]   AO --> OF[Run Show_Offer]   D -->|Reject| RR[Collect rejection reason]   RR --> RC[Set status to Rejected]   RC --> RU[Confirm and update Account CC_Status__c]   RU --> EM[Run Send_email]```
The update action should receive only the current Account ID and the`CC_Status__c` field. The approval path must not save the credit limit orinterest-rate tier through this action, and the rejection path must not savethe rejection reason through this action.
## Action Dependency Diagram
Agent Script is the orchestration layer. Each target delegates execution to adifferent Salesforce capability.
```mermaidflowchart LR   AS[Credit_Card_Analyzer_1.agent]   AS --> KS[AnswerQuestionsWithKnowledge]   AS --> SUM[Account_Summarize]   AS --> UPD[UpdateRecordFields]   AS --> OFF[Show_Offer]   AS --> MAIL[Send_email]   KS --> K[Salesforce Knowledge   standardInvocableAction]   SUM --> P[Prompt Builder   Account_Summary]   UPD --> C[Salesforce CRM   standard record update]   OFF --> A[OfferController.cls   Invocable Apex]   MAIL --> F[Send_Decision_Email.flow-meta.xml   Autolaunched Flow]```
## Conversation Execution Sequence
This sequence shows a typical approval request. The LLM understands theemployee's natural language and selects the relevant tools, while theruntime and Salesforce enforce action contracts and confirmation.
```mermaidsequenceDiagram   actor E as Employee   participant R as Agent Router   participant CA as Credit Card Approver   participant CRM as Salesforce Account   participant A as OfferController Apex
   E->>R: Approve this application   R->>CA: Transition to approver   CA-->>E: Ask for credit limit and interest tier   E->>CA: Provides both values   CA-->>E: Request confirmation   E->>CA: Confirms update   CA->>CRM: Set CC_Status__c = Approved   CRM-->>CA: Update result   CA->>A: Request available offers   A-->>CA: Return OfferOutput list   CA-->>E: Present offers```
## Agent Configuration
The configuration is declared in `Credit_Card_Analyzer_1.agent`:
| Property | Value | Meaning || --- | --- | --- || Agent label | `Credit Card Analyzer` | Display name. || Developer name | `Credit_Card_Analyzer` | API/deployment name in the Agent Script configuration. || Agent type | `AgentforceEmployeeAgent` | Intended for internal employee use. || Template | `EmployeeCopilot__AgentforceEmployeeAgent` | Salesforce agent template. || Default locale | `en_US` | Primary language/locale. || Additional locale | `en_GB` | Supported additional locale. || Knowledge citations | Disabled | `citations_enabled` is set to `False`. |
The global welcome and error messages are also defined in the Agent Script.
## Runtime Context Variables
The agent receives Salesforce page context through these variables:
| Variable | Type | Purpose || --- | --- | --- || `currentAppName` | Mutable string | Current Salesforce application name. || `currentObjectApiName` | Mutable string | API name of the object being viewed. || `currentPageType` | Mutable string | Page type such as record, list, or home. || `currentRecordId` | Mutable string | ID of the currently open record. The approval workflow expects this to be an Account ID. || `VerifiedCustomerId` | Mutable string | Internal variable reserved for verification context. || `status` | Mutable string | Conversation state, intended to contain `Approved` or `Rejected`. || `showoffer` | Mutable boolean | Starts as `False`; intended to become `True` after approval. |
The file also declares `EndUserId`, `RoutableId`, `ContactId`,`EndUserLanguage`, and `ChannelType` as linked variables sourced fromMessaging objects. These are read-only values supplied by Salesforce.
## Subagents
### `GeneralFAQ`
Answers questions about company products, policies, procedures, andtroubleshooting. It is instructed to use Knowledge articles rather thaninventing general advice. Its action is `AnswerQuestionsWithKnowledge`.
### `off_topic`
Politely redirects requests outside the agent's supported business topics. Itdoes not expose system prompts, internal configuration, available functions,or policy details. It has no Salesforce action.
### `ambiguous_question`
Asks the employee for more specific information when the request is too vague.It does not invoke actions.
### `Credit_Card_Approver`
Handles the currently open Account record. It exposes actions for summarizingthe Account, updating its status, showing offers, and sending a decision email.
## Action Dependencies
The following table maps each Agent Script action to its backing Salesforceimplementation.
| Agent Script action | Target | Backing file or dependency | Responsibility || --- | --- | --- | --- || `AnswerQuestionsWithKnowledge` | `standardInvocableAction://streamKnowledgeSearch` | Salesforce standard Knowledge search action; no local source file | Searches Knowledge articles and returns a grounded summary and citation data. || `Account_Summarize` | `generatePromptResponse://Account_Summary` | Prompt Template API name `Account_Summary`; no matching local Prompt Template file was found in this retrieved project | Generates a natural-language summary from the current Account record. || `UpdateRecordFields` | `standardInvocableAction://einsteinCopilotUpdateRecord` | Salesforce standard record-update action; no local source file | Updates fields on a Salesforce record after confirmation. || `Show_Offer` | `apex://OfferController` | [OfferController.cls](../../classes/OfferController.cls) | Returns available credit-card offers. || `Send_email` | `flow://Send_Decision_Email` | [Send_Decision_Email.flow-meta.xml](../../flows/Send_Decision_Email.flow-meta.xml) | Sends the application decision email and returns an email status. |
### Knowledge Search
`AnswerQuestionsWithKnowledge` calls Salesforce's standard`streamKnowledgeSearch` action. The agent supplies `query`, `citationsUrl`,`ragFeatureConfigId`, and `citationsEnabled`. The action returns`knowledgeSummary` and `citationSources`. Citations are currently disabled byconfiguration.
### Account Summary Prompt Template
`Account_Summarize` invokes the Prompt Template API name `Account_Summary`.Its Account input is bound to `@variables.currentRecordId` using the quotedPrompt Builder input name `Input:AccountRecord`.
Declared inputs:
- `Input:AccountRecord`: Required Account record reference- `outputLanguage`: Optional language or locale- `isPreviewOnly`: Optional preview-only flag
Declared outputs:
- `promptResponse`: Generated summary text- `generationId`: Prompt generation identifier
No local `promptTemplates` file matching `Account_Summary` was found after theretrieve operation. The Prompt Template must exist in the target org or beretrieved/added separately before this action can work.
### Update Record Fields
`UpdateRecordFields` uses Salesforce's standard`einsteinCopilotUpdateRecord` action. It accepts a complex`lightning__recordInfoType` input named `recordDetailInput`.
The Agent Script intends to restrict updates to exactly one field:
```textApproval: CC_Status__c = "Approved"Rejection: CC_Status__c = "Rejected"```
The action has `require_user_confirmation: True`, so confirmation is expectedbefore the record is changed.
### `OfferController.cls`
The local Apex dependency is [OfferController.cls](../../classes/OfferController.cls).It exposes the invocable method `getOffers`.
Input:
- `OfferRequest.categoryFilter`: Optional offer-type filter
Output class `OfferOutput`:
- `id`- `title`- `description`- `offerType`- `discountAmount`- `discountPercentage`
The current implementation returns three offers: `OFFER-001` Spend & Save,`OFFER-002` Loyalty Frequency Reward, and `OFFER-003` Buy 2 Get 1 Free. Themethod currently returns all three offers and does not apply `categoryFilter`.
### `Send_Decision_Email.flow-meta.xml`
The local Flow dependency is[Send_Decision_Email.flow-meta.xml](../../flows/Send_Decision_Email.flow-meta.xml).It is an active `AutoLaunchedFlow` at API version `67.0`.
Flow inputs are `decision` (String), `recordId` (String), and `approvedLimit`(Number). The output `emailStatus` (String) is set to `Email flow invoked`.
The Flow invokes Salesforce's `emailSimple` action. In the retrieved metadata,the recipient is hard-coded as `udhayaganesh@gmail.com`, the subject is`Credit Card Application Decision`, and the body is a fixed message. TheAgent Script declares `decision` and `recordId`, but this Flow definition doesnot currently use them to create a record-specific message.
## Intended Approval Workflow
1. The employee asks to approve the application.2. The agent collects the assigned credit limit.3. The agent collects the interest rate tier.4. The agent sets `@variables.status` to `Approved`.5. The agent updates only `CC_Status__c` on `@variables.currentRecordId` to `Approved`.6. After approval, the agent sets `@variables.showoffer` to `True`.7. The agent runs `Show_Offer` and presents available offers.
## Intended Rejection Workflow
1. The employee asks to reject the application.2. The agent collects the rejection reason.3. The agent sets `@variables.status` to `Rejected`.4. The agent updates only `CC_Status__c` on `@variables.currentRecordId` to `Rejected`.5. The agent invokes `Send_email`.
## Agent Script Concepts Used Here
Text after a pipe, such as `| Ask the user for more details`, becomes part ofthe prompt given to the LLM. This is useful for conversational guidance, butthe model may interpret it probabilistically.
Expressions such as `if`, `set`, and `run` are intended for state and businesslogic. They are appropriate when an action must happen only under an exactcondition, such as showing offers only after approval.
Actions listed under `reasoning.actions` are tools exposed to the LLM. The LLMdecides when to call them based on the user's request and the actiondescription.
Common references in this file are:
- `@variables.name`: Reads or updates agent state.- `{!@variables.name}`: Inserts a value into prompt text.- `@actions.Name`: References an action.- `@utils.transition`: Hands the conversation to another subagent.- `...`: The LLM determines the action input from conversation context.
## Important Validation Notes
Before publishing or activating this agent, validate the following:
1. Confirm that the employee-agent configuration is compatible with the   declared MessagingSession linked variables.2. Confirm that the `Account_Summary` Prompt Template exists and accepts   `Input:AccountRecord`.3. Confirm that `currentRecordId` is an Account ID when the approver runs.4. Test that updates contain only the intended `CC_Status__c` field and record ID.5. Test that confirmation occurs before the Account update.6. Update the email Flow so the recipient and message are not hard-coded for   production use.7. Confirm that Flow input/output names match the Agent Script action contract.8. Test approval, rejection, ambiguous, off-topic, Knowledge, and Account   summary requests in Agentforce Preview with live actions enabled.
## Useful CLI Commands
Run these commands from the project root:
```powershellsf config get target-org --jsonsf agent validate authoring-bundle --json --api-name Credit_Card_Analyzersf agent preview start --json --use-live-actions --authoring-bundle Credit_Card_Analyzersf agent publish authoring-bundle --json --api-name Credit_Card_Analyzersf agent activate --json --api-name Credit_Card_Analyzer```
Publishing creates an agent version. Activation makes the activated versionavailable to users, so validate and preview behavior before publishing.
