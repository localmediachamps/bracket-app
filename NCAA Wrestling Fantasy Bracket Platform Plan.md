# **NCAA Wrestling Fantasy Bracket Platform**

Act as a senior product engineer and build a responsive web application for fantasy NCAA-style wrestling tournaments.

The platform should let tournament administrators create digital wrestling tournaments from uploaded bracket PDFs, let users predict the winner of every matchup, score those predictions as tournament results are entered, and compare users through global and private-group leaderboards.

## **1\. Product Concept**

This product combines:

* NCAA-style wrestling tournament brackets  
* March Madness-style bracket predictions  
* Fantasy sports leaderboards  
* Private groups for friends, teams, clubs, or organizations  
* Tournament analytics and live scoring

This is not primarily a traditional fantasy draft system. The main gameplay mechanic is predicting the outcome of every possible matchup in a tournament bracket.

For every weight class, a user completes the entire bracket by choosing the winner of each match. As official tournament results are entered, the system scores each submitted bracket based on prediction accuracy.

## **2\. Primary User Types**

### **Tournament Administrator**

A tournament administrator can:

* Create a tournament manually  
* Create a tournament by uploading a PDF bracket  
* Review and correct information extracted from the PDF  
* Configure weight classes, competitors, seeds, schools, and bracket structure  
* Publish or unpublish a tournament  
* Set the prediction deadline  
* Enter or import official match results  
* Correct previously entered results  
* View tournament-wide participation and scoring analytics

### **Player**

A player can:

* Create an account and profile  
* Browse available tournaments  
* Open a tournament and inspect each weight-class bracket  
* Predict the winner of every match  
* Save an incomplete bracket as a draft  
* Submit and lock a completed bracket  
* Join private groups  
* Create private groups  
* Track prediction accuracy and points  
* Compare performance against other players  
* Review correct and incorrect predictions after results become public

### **Group Owner or Administrator**

A group owner can:

* Create a private or public fantasy group for a specific tournament  
* Generate an invitation link or invitation code  
* Approve members when approval is required  
* Remove members  
* View the group leaderboard  
* Configure a group name, description, logo, and privacy settings

## **3\. Core User Experience**

### **Tournament Creation**

An administrator should be able to create a tournament in two ways.

#### **Option A: Upload a PDF Bracket**

The administrator uploads a PDF containing one or more wrestling brackets.

The system should:

1. Store the original PDF securely.  
2. Extract text and structural information from the document.  
3. Identify:  
   * Tournament name  
   * Tournament date  
   * Weight classes  
   * Competitor names  
   * Schools or clubs  
   * Seeds  
   * Match numbers  
   * Bracket positions  
   * Byes  
   * Championship paths  
   * Consolation paths, when available  
4. Convert the extracted information into structured tournament data.  
5. Present an import-review screen.  
6. Highlight uncertain or missing fields.  
7. Allow the administrator to edit all extracted data.  
8. Display a preview of the generated digital bracket.  
9. Require administrator confirmation before publishing.

Do not assume that every PDF follows the same format. Build the PDF import process as a flexible ingestion pipeline with a required human review step.

The importer should preserve extraction confidence and source-location metadata where practical so administrators can understand which values may need correction.

#### **Option B: Manual Tournament Builder**

The administrator can manually define:

* Tournament name  
* Tournament description  
* Event dates  
* Prediction deadline  
* Weight classes  
* Competitors  
* Seeds  
* Schools  
* Bracket size  
* Byes  
* Match relationships  
* Championship bracket  
* Consolation bracket  
* Placement matches

### **Tournament Browsing**

Players should see a tournament directory containing:

* Upcoming tournaments  
* Open tournaments  
* Locked tournaments  
* Live tournaments  
* Completed tournaments

Each tournament card should show:

* Tournament name  
* Date  
* Location, if available  
* Number of weight classes  
* Number of competitors  
* Prediction deadline  
* Tournament status  
* Number of participating fantasy players

### **Bracket Prediction Experience**

A player opens a tournament and sees a tab or navigation item for every weight class.

For each weight class:

* Display a polished, interactive bracket.  
* Allow horizontal scrolling on smaller screens.  
* Allow zooming or collapsing bracket rounds.  
* Clearly display competitor name, seed, school, and record when available.  
* Let the player click or tap a competitor to advance that wrestler.  
* Automatically propagate the selected winner into the next match.  
* Recalculate downstream selections when an earlier pick changes.  
* Visually distinguish completed and incomplete matches.  
* Show completion progress for each weight class.  
* Show total tournament prediction progress.

Users must predict every match required by the tournament configuration.

The system should support:

* Standard championship brackets  
* Byes  
* Preliminary rounds  
* Pigtail matches  
* Consolation brackets  
* Placement matches  
* Different bracket sizes across weight classes

### **Drafting and Submission**

Players can save predictions as drafts until the deadline.

Before submission:

* Validate that all required matches have a selected winner.  
* Show unresolved or incomplete matches.  
* Show a summary of selected champions and placement predictions.  
* Warn the player that the bracket will lock at the configured deadline.

Submission behavior:

* A player may edit a submitted bracket before the deadline.  
* At the deadline, all entries become locked.  
* Administrators should not casually modify a user’s locked entry.  
* Any administrative override must be logged in an audit trail.  
* Late entries should be disabled by default but configurable by tournament administrators.

## **4\. Scoring System**

The scoring model should resemble March Madness bracket challenges.

Points are awarded for correctly predicting the winner of a match. Later rounds should generally be worth more than earlier rounds.

Create a configurable scoring system rather than hard-coding one scoring table.

A default scoring configuration could include:

* Preliminary or pigtail match: 1 point  
* First championship round: 1 point  
* Second championship round: 2 points  
* Quarterfinal: 4 points  
* Semifinal: 8 points  
* Championship: 16 points  
* Consolation rounds: configurable values  
* Placement matches: configurable values  
* Correct tournament champion bonus: optional  
* Correct final placement bonus: optional

The administrator should be able to configure scoring by:

* Bracket type  
* Round  
* Match importance  
* Weight class, if needed

Scoring requirements:

* Scores must update when official match results are entered.  
* Scores must recalculate when results are corrected.  
* Users should see earned points and possible remaining points.  
* Users should see the maximum score they can still achieve.  
* The system should identify predictions that are mathematically eliminated.  
* Scoring calculations should be deterministic and reproducible.  
* Maintain an audit trail of result and score changes.  
* Store scoring rule versions so historical tournaments remain accurate if scoring defaults later change.

### **Suggested Tie-Breakers**

Make tie-breakers configurable.

Possible default order:

1. Total points  
2. Number of correctly predicted champions  
3. Number of correctly predicted finalists  
4. Number of correct semifinal picks  
5. Championship-match score prediction, if that feature is enabled  
6. Earliest valid submission time

## **5\. Tournament Results Management**

Administrators need an efficient result-entry interface.

For each match, the administrator should be able to select:

* Winner  
* Loser  
* Match status  
* Score  
* Victory type  
* Timestamp  
* Notes

Possible victory types include:

* Decision  
* Major decision  
* Technical fall  
* Fall  
* Medical forfeit  
* Injury default  
* Disqualification  
* Forfeit

The prediction game initially scores match winners rather than exact match scores or victory methods. Design the data model so additional scoring categories can be introduced later.

Result states should include:

* Not started  
* In progress  
* Completed  
* Under review  
* Corrected  
* Cancelled

When a result is entered:

1. Update the official bracket.  
2. Advance the winning wrestler.  
3. Determine which user predictions were correct.  
4. Recalculate affected user scores.  
5. Recalculate global and group leaderboards.  
6. Update possible remaining points.  
7. Notify affected users when notifications are enabled.

Use background jobs or a task queue for expensive score recalculations.

## **6\. Leaderboards**

### **Tournament-Wide Leaderboard**

Every published tournament should have a global leaderboard.

Display:

* Rank  
* Player name  
* Avatar  
* Total points  
* Possible remaining points  
* Correct predictions  
* Total scored predictions  
* Accuracy percentage  
* Correct champions  
* Rank change  
* Submission status  
* Last score update

Include filters for:

* Overall standings  
* Weight class  
* Group  
* Friends  
* Completed matches only  
* Current round

### **Private Group Leaderboard**

Users should be able to create smaller fantasy groups tied to a tournament.

A group includes:

* Name  
* Description  
* Tournament  
* Owner  
* Administrators  
* Members  
* Privacy setting  
* Invitation code  
* Invitation link  
* Optional password  
* Optional member limit

Privacy modes:

* Public  
* Unlisted  
* Private by invitation  
* Private with approval

Each tournament entry should exist once per user. Groups should reference the user’s tournament entry rather than forcing the player to complete a different bracket for every group.

A player may use the same tournament entry in multiple groups.

### **Head-to-Head Comparison**

Allow users to compare two entries.

Show:

* Total points  
* Current rank  
* Maximum possible points  
* Picks in common  
* Picks that differ  
* Correct picks  
* Incorrect picks  
* Remaining decisive matches  
* Predicted champions by weight class

## **7\. Analytics**

### **Player Analytics**

Provide:

* Overall prediction accuracy  
* Accuracy by tournament  
* Accuracy by weight class  
* Accuracy by round  
* Accuracy by seed matchup  
* Champion prediction accuracy  
* Historical finishes  
* Average percentile  
* Best tournament finish  
* Current and historical streaks  
* Most successful weight classes

### **Tournament Analytics**

Provide administrators with:

* Total entries  
* Completed entries  
* Draft entries  
* Group count  
* Most-picked champion by weight class  
* Pick distribution for every match  
* Most common upset predictions  
* Most correctly predicted matches  
* Most incorrectly predicted matches  
* Average player score  
* Score distribution  
* Entry activity over time  
* Prediction completion funnel

### **Pick Popularity**

After entries lock, players may view:

* Percentage of players selecting each wrestler  
* Percentage selecting each finalist  
* Percentage selecting each champion  
* Popular upset selections  
* Contrarian picks

Do not expose aggregate pick percentages before the deadline unless the tournament explicitly enables that feature.

## **8\. Suggested Domain Model**

Create a relational data model with entities similar to the following.

### **User**

* id  
* email  
* username  
* displayName  
* avatarUrl  
* role  
* createdAt  
* updatedAt

### **Tournament**

* id  
* name  
* slug  
* description  
* location  
* startDate  
* endDate  
* predictionDeadline  
* status  
* visibility  
* createdBy  
* scoringConfigurationId  
* sourcePdfId  
* publishedAt  
* createdAt  
* updatedAt

### **WeightClass**

* id  
* tournamentId  
* name  
* numericWeight  
* displayOrder  
* bracketType  
* status

### **Competitor**

* id  
* tournamentId  
* weightClassId  
* name  
* normalizedName  
* school  
* seed  
* record  
* externalId  
* metadata

### **Match**

* id  
* tournamentId  
* weightClassId  
* bracketSection  
* round  
* roundNumber  
* matchNumber  
* displayOrder  
* topSourceMatchId  
* bottomSourceMatchId  
* topCompetitorId  
* bottomCompetitorId  
* winnerDestinationMatchId  
* loserDestinationMatchId  
* winnerId  
* loserId  
* status  
* officialScore  
* victoryType  
* startedAt  
* completedAt  
* version

The match model must support both championship and consolation movement.

Avoid representing a bracket only as static visual coordinates. Store the bracket as a directed match graph and derive the visual layout from that structure.

### **TournamentEntry**

* id  
* tournamentId  
* userId  
* status  
* submittedAt  
* lockedAt  
* totalPoints  
* possiblePoints  
* correctPickCount  
* scoredPickCount  
* scoringVersion  
* createdAt  
* updatedAt

Enforce one primary entry per user per tournament for the initial version.

### **Prediction**

* id  
* tournamentEntryId  
* matchId  
* predictedWinnerId  
* pointsAvailable  
* pointsEarned  
* outcomeStatus  
* createdAt  
* updatedAt

Possible prediction outcome states:

* Pending  
* Correct  
* Incorrect  
* Eliminated  
* Void

### **FantasyGroup**

* id  
* tournamentId  
* name  
* slug  
* description  
* ownerId  
* privacy  
* invitationCode  
* passwordHash  
* memberLimit  
* createdAt  
* updatedAt

### **GroupMembership**

* id  
* groupId  
* userId  
* role  
* status  
* joinedAt

### **ScoringConfiguration**

* id  
* name  
* version  
* tournamentId  
* rules  
* tieBreakerRules  
* createdAt

Store the rules in a versioned format while retaining queryable fields for commonly used calculations.

### **UploadedDocument**

* id  
* uploadedBy  
* fileName  
* storageKey  
* mimeType  
* fileSize  
* checksum  
* processingStatus  
* extractionResult  
* createdAt

### **ImportIssue**

* id  
* uploadedDocumentId  
* tournamentId  
* severity  
* category  
* pageNumber  
* sourceText  
* fieldName  
* proposedValue  
* confidence  
* resolutionStatus  
* resolvedBy  
* resolvedAt

### **AuditLog**

* id  
* actorId  
* entityType  
* entityId  
* action  
* previousValue  
* newValue  
* metadata  
* createdAt

## **9\. PDF Import Architecture**

Implement PDF processing as a multi-step pipeline.

### **Pipeline Stages**

1. Upload and validate the file.  
2. Scan for invalid or malicious content.  
3. Extract embedded text.  
4. Render pages as images when necessary.  
5. Identify bracket regions.  
6. Identify weight-class headings.  
7. Extract competitors, seeds, schools, and match relationships.  
8. Normalize names and school labels.  
9. Assign confidence scores.  
10. Generate a draft match graph.  
11. Detect structural inconsistencies.  
12. Present the results for administrator review.  
13. Save the approved tournament.

Potential extraction methods may include:

* Native PDF text extraction  
* Table and line detection  
* Layout-aware document parsing  
* OCR for image-based PDFs  
* Template-specific parsers  
* AI-assisted structured extraction

Create an adapter or plugin interface for bracket parsers so support for common PDF providers can be added later without rewriting the entire import system.

Example conceptual interface:

interface BracketParser {  
  canParse(document: ParsedDocument): Promise\<ParserConfidence\>;  
  parse(document: ParsedDocument): Promise\<ImportedTournamentDraft\>;  
  validate(draft: ImportedTournamentDraft): ValidationIssue\[\];  
}

The platform must not silently publish an incorrectly parsed bracket. Every PDF-created tournament should pass through an administrator review and validation screen.

### **Import Validation**

Detect issues such as:

* Duplicate competitors  
* Missing competitors  
* Duplicate seeds  
* Invalid seed numbers  
* Matches with only one participant that are not marked as byes  
* Broken winner paths  
* Broken consolation paths  
* Circular match dependencies  
* Multiple destination matches  
* Missing weight classes  
* Competitors assigned to multiple weight classes  
* Unrecognized bracket sections

## **10\. Bracket Rendering**

Create a reusable bracket-rendering component driven by structured match data.

Requirements:

* Desktop and mobile support  
* Horizontal scrolling  
* Zoom controls  
* Pan controls  
* Round headers  
* Championship and consolation sections  
* Match connector lines  
* Competitor seeds and schools  
* Bye indicators  
* Live-result states  
* Prediction states  
* Correct and incorrect pick states  
* Accessible keyboard navigation  
* Screen-reader labels  
* Touch-friendly selection targets

The same component should support several modes:

* Administrator preview  
* Player prediction  
* Live tournament results  
* Read-only completed bracket  
* Pick comparison

Do not tightly couple the bracket UI to a single fixed bracket size.

## **11\. Tournament Lifecycle**

Use explicit tournament states.

Suggested states:

* Draft  
* Importing  
* Needs review  
* Open for predictions  
* Predictions locked  
* Live  
* Completed  
* Archived  
* Cancelled

Define allowed transitions and validate them on the server.

Example:

* Draft → Open for predictions  
* Importing → Needs review  
* Needs review → Open for predictions  
* Open for predictions → Predictions locked  
* Predictions locked → Live  
* Live → Completed  
* Completed → Archived

Administrators may reopen a tournament only through a controlled action that creates an audit-log record.

## **12\. Notifications**

Design a notification system for:

* Tournament opened  
* Prediction deadline approaching  
* Entry incomplete  
* Entry locked  
* Group invitation  
* Group member joined  
* Tournament started  
* Rank changed significantly  
* Official result entered  
* Tournament completed  
* Final group standings available

Support in-app notifications first. Structure the system so email and push notifications can be added later.

## **13\. Authentication and Authorization**

Support secure account authentication.

Possible options:

* Email and password  
* Magic link  
* Google sign-in  
* Apple sign-in

Role and permission examples:

* Platform administrator  
* Tournament administrator  
* Group owner  
* Group administrator  
* Player

Authorization must be enforced server-side.

A user must not be able to:

* Edit another player’s predictions  
* View private groups without authorization  
* Enter official results without tournament permissions  
* Change locked predictions through direct API calls  
* Access original uploaded documents without permission  
* Modify scoring rules after results have started without an audited workflow

## **14\. API and Service Boundaries**

Create clear modules or services for:

* Authentication  
* Users  
* Tournaments  
* PDF ingestion  
* Bracket validation  
* Bracket rendering data  
* Tournament entries  
* Predictions  
* Results  
* Scoring  
* Leaderboards  
* Groups  
* Analytics  
* Notifications  
* Audit logs

Use transactions when entering results and recalculating affected match state.

Make score recalculation idempotent. Reprocessing the same official result should not duplicate points.

Consider event-based domain actions such as:

* TournamentPublished  
* PredictionsLocked  
* MatchResultRecorded  
* MatchResultCorrected  
* EntryScoreUpdated  
* LeaderboardUpdated  
* TournamentCompleted

## **15\. Non-Functional Requirements**

### **Performance**

* Load tournament summaries quickly.  
* Use pagination for large leaderboards.  
* Cache public tournament data.  
* Cache leaderboard results where appropriate.  
* Recalculate only the users and predictions affected by a result when possible.  
* Support at least several thousand entries in a single tournament for the initial production architecture.  
* Avoid loading an entire tournament’s analytics into the browser unnecessarily.

### **Reliability**

* Use database constraints for uniqueness and referential integrity.  
* Create recoverable background jobs.  
* Record failed PDF processing attempts.  
* Allow administrators to retry imports.  
* Maintain historical score records or reproducible score events.  
* Back up tournament and prediction data.

### **Security**

* Validate PDF type, size, and content.  
* Use secure object storage.  
* Use signed URLs for protected files.  
* Sanitize extracted and user-entered text.  
* Rate-limit authentication, invitations, and result-entry endpoints.  
* Protect against unauthorized prediction changes.  
* Hash invitation passwords.  
* Do not expose private group invitation codes unnecessarily.

### **Accessibility**

* Meet WCAG 2.1 AA where practical.  
* Ensure the prediction workflow works without a mouse.  
* Provide nonvisual alternatives for understanding bracket progression.  
* Do not use color as the only indicator of prediction correctness.

### **Observability**

Include:

* Structured logs  
* Error tracking  
* Background-job monitoring  
* PDF-import metrics  
* Scoring-recalculation metrics  
* Audit events  
* Performance monitoring

## **16\. Recommended MVP Scope**

Build the first version around the smallest complete game loop.

### **MVP Must Include**

1. User authentication  
2. User profiles  
3. Manual tournament creation  
4. PDF upload and draft extraction  
5. Administrator import-review interface  
6. Weight classes  
7. Competitors and seeds  
8. Championship bracket support  
9. Basic consolation bracket support  
10. Interactive full-bracket predictions  
11. Draft saving  
12. Entry submission and deadline locking  
13. Manual official result entry  
14. Configurable round-based scoring  
15. Tournament-wide leaderboard  
16. Private groups with invitation links or codes  
17. Group leaderboards  
18. Basic player analytics  
19. Audit logs for result corrections  
20. Responsive desktop and mobile UI

### **Defer Until After MVP**

* Native mobile applications  
* Real-time data feeds from tournament providers  
* Paid contests  
* Entry fees  
* Cash prizes  
* Advanced social feeds  
* Direct messaging  
* Multiple entries per user  
* Exact-score predictions  
* Victory-method predictions  
* Automated school and wrestler statistics  
* Full support for every historical PDF format  
* Complex commissioner scoring formulas  
* Live chat  
* Sportsbook-style odds  
* Automated public-web bracket downloading

Do not build automated downloading from arbitrary websites in the MVP. Start with user-uploaded PDF files to reduce legal, reliability, and scraping complexity.

## **17\. Suggested Application Pages**

### **Public Pages**

* Landing page  
* Tournament directory  
* Tournament overview  
* Public leaderboard  
* Public group page  
* Sign-in  
* Registration

### **Player Pages**

* Dashboard  
* My tournaments  
* My entries  
* Prediction editor  
* Entry review  
* Entry results  
* Groups  
* Group leaderboard  
* Head-to-head comparison  
* Profile  
* Notification center

### **Administrator Pages**

* Admin dashboard  
* Create tournament  
* Upload bracket PDF  
* PDF processing status  
* Import review  
* Tournament builder  
* Bracket editor  
* Competitor editor  
* Scoring configuration  
* Result entry  
* Tournament analytics  
* Audit history

## **18\. Important Edge Cases**

Account for:

* A competitor withdrawing before the tournament  
* A competitor changing weight classes  
* A replacement competitor  
* A tournament reseeding its bracket  
* A match being removed  
* A result being overturned  
* A double forfeit  
* A medical forfeit  
* A bye  
* A bracket with a non-power-of-two field  
* A user leaving and rejoining a group  
* A group invitation being shared publicly  
* A tournament deadline changing  
* Picks saved at the exact locking time  
* Two administrators entering a result simultaneously  
* A result correction after dependent matches have been entered  
* An imported PDF containing multiple tournaments  
* A PDF containing championship brackets but no consolation brackets  
* Two competitors with the same name  
* Different spellings of the same school  
* A competitor appearing more than once due to OCR errors

Use optimistic concurrency control or record versioning for result entry and bracket changes.

## **19\. Acceptance Criteria for the Main Game Loop**

The MVP is functionally complete when the following scenario works:

1. An administrator creates an account.  
2. The administrator uploads a tournament bracket PDF.  
3. The system extracts weight classes, competitors, seeds, and match structure.  
4. The administrator corrects extraction errors.  
5. The administrator publishes the tournament.  
6. A player creates an account.  
7. The player opens the tournament.  
8. The player predicts every match across all weight classes.  
9. The player submits the entry.  
10. The prediction deadline passes and the entry locks.  
11. The administrator enters official results.  
12. The system scores the player’s predictions.  
13. The tournament leaderboard updates.  
14. The player creates a private group.  
15. Other players join the group.  
16. The group leaderboard displays only group members.  
17. The administrator corrects a result.  
18. Scores and leaderboards recalculate correctly.  
19. The final tournament and group standings are displayed.  
20. Every sensitive modification is represented in an audit log.

## **20\. Development Approach**

Start by producing:

1. A concise system architecture.  
2. A database schema.  
3. The match-graph and bracket-progression model.  
4. The scoring algorithm.  
5. The tournament state machine.  
6. The PDF-import architecture.  
7. API endpoint definitions.  
8. Page and component hierarchy.  
9. Background-job design.  
10. A phased implementation plan.

Then build the application incrementally.

Suggested implementation order:

### **Phase 1: Foundation**

* Project setup  
* Authentication  
* Database  
* Roles and permissions  
* Tournament CRUD  
* Weight classes  
* Competitors

### **Phase 2: Bracket Engine**

* Match graph  
* Bracket validation  
* Manual bracket builder  
* Bracket renderer  
* Winner advancement  
* Consolation paths

### **Phase 3: Fantasy Entries**

* Entry creation  
* Prediction editing  
* Draft saving  
* Submission  
* Deadline locking  
* Entry validation

### **Phase 4: Results and Scoring**

* Result entry  
* Score calculation  
* Score correction  
* Leaderboards  
* Possible-points calculation  
* Audit logging

### **Phase 5: Groups**

* Group creation  
* Invitation codes  
* Membership  
* Group leaderboards  
* Head-to-head comparison

### **Phase 6: PDF Import**

* File storage  
* Text extraction  
* OCR fallback  
* Parser interface  
* Import review  
* Validation and correction tools

### **Phase 7: Analytics and Polish**

* Player analytics  
* Tournament analytics  
* Notifications  
* Accessibility  
* Mobile optimization  
* Performance improvements

## **21\. Testing Requirements**

Include:

* Unit tests for scoring rules  
* Unit tests for match advancement  
* Unit tests for consolation movement  
* Unit tests for possible-points calculations  
* Unit tests for tie-breakers  
* Integration tests for result correction  
* Integration tests for entry locking  
* Integration tests for group permissions  
* Import tests using several different PDF layouts  
* End-to-end tests for the full acceptance scenario  
* Authorization tests for all protected actions  
* Concurrency tests for result entry

Create fixture tournaments containing:

* Eight-person bracket  
* Sixteen-person bracket  
* Thirty-two-person bracket  
* Bracket with byes  
* Bracket with pigtail matches  
* Championship-only bracket  
* Championship and consolation bracket  
* Multiple weight classes with different bracket sizes

## **22\. Initial Technical Decisions**

Unless an existing repository dictates otherwise, choose a modern, production-ready web stack with:

* Type-safe frontend and backend development  
* Relational database support  
* Background-job processing  
* Object storage for PDFs  
* Server-side authorization  
* Responsive UI components  
* Strong testing support

Prioritize correctness of the bracket graph and scoring engine over visual polish during the earliest implementation stages.

Do not treat the PDF parser as the source of truth. The administrator-approved structured tournament data is the source of truth.

Do not implement the bracket as a collection of hard-coded HTML columns. Build a reusable bracket engine backed by match relationships.

Do not calculate leaderboard scores only in the browser. Scoring must be performed and validated on the server.

## **23\. Deliverables**

Provide the following before or alongside implementation:

* Architecture overview  
* Entity relationship diagram  
* Database migrations  
* Match graph specification  
* Scoring specification  
* Tournament state-transition table  
* API specification  
* PDF ingestion sequence diagram  
* Wireframes or component map  
* MVP implementation plan  
* Seed data  
* Automated tests  
* Local development instructions  
* Deployment instructions  
* Known limitations

When requirements are ambiguous, make a reasonable documented assumption and keep the implementation configurable. Avoid blocking progress on minor product decisions.

## **Historical Results Archive and Future Prediction Layer**

The platform must permanently preserve official tournament, competitor, match, bracket, and scoring data after a tournament is completed.

Completed tournaments should not be treated as temporary fantasy contests. They should become part of a continuously growing historical wrestling dataset that can later support:

* Match outcome predictions  
* Tournament placement predictions  
* Upset probabilities  
* Wrestler performance ratings  
* Head-to-head analysis  
* Seed-performance analysis  
* School and team performance trends  
* Weight-class trends  
* Fantasy pick recommendations  
* Predictive bracket generation  
* Model training, validation, and backtesting

The initial product does not need to provide automated predictions, but all data architecture and result-entry workflows must be designed so a prediction layer can be added later without restructuring the core database.

### **Permanent Historical Records**

Once official results are entered, preserve the following information indefinitely:

* Tournament metadata  
* Tournament date and location  
* Tournament level and classification  
* Tournament format  
* Weight classes  
* Original bracket structure  
* Seeds  
* Competitors  
* Schools or clubs  
* Every match  
* Match round and bracket section  
* Wrestler starting position  
* Winner and loser  
* Match score  
* Victory type  
* Placement result  
* Advancement path  
* Consolation path  
* Byes  
* Forfeits  
* Injury defaults  
* Withdrawals  
* Result corrections  
* Source documents  
* Data provenance  
* Fantasy predictions  
* Pick popularity  
* Fantasy scoring outcomes  
* Final leaderboards

Do not delete completed tournament records when a tournament is archived. Archiving should only remove the tournament from active views.

### **Immutable Historical Identity**

Historical results must remain reproducible even when a wrestler, school, tournament, or scoring configuration is later edited.

Use stable identifiers and historical snapshots so that changes to current profile information do not rewrite the past.

For example, if a wrestler later:

* Changes schools  
* Changes weight classes  
* Updates their name  
* Receives a new external identifier  
* Merges with a duplicate profile

the historical tournament record must continue to show the wrestler’s information as it existed when that tournament occurred.

Store both:

1. A reference to the canonical wrestler identity.  
2. A tournament-specific snapshot of the wrestler’s name, school, seed, weight class, and other relevant attributes.

Apply the same pattern to schools, tournaments, scoring configurations, and other entities whose information can change over time.

### **Canonical Wrestler Profiles**

Introduce a canonical wrestler entity that can connect the same competitor across multiple tournaments.

Suggested fields include:

* id  
* canonicalName  
* normalizedName  
* dateOfBirth, when legally and appropriately available  
* hometown, when available  
* graduationYear  
* currentSchoolId  
* externalIdentifiers  
* profileStatus  
* createdAt  
* updatedAt

Tournament-specific competitor records should reference the canonical wrestler when a reliable match can be made.

The system must support:

* Unlinked tournament competitors  
* Manual identity matching  
* Suggested identity matches  
* Duplicate profile merging  
* Match confidence scores  
* Identity corrections  
* Audit logs for profile merges and splits

Do not automatically merge wrestler identities based only on matching names. Two wrestlers may share the same name, and the same wrestler may appear under different spellings.

### **Historical Match Record**

Create a durable historical match record separate from temporary UI state.

Suggested fields include:

* id  
* tournamentId  
* weightClassId  
* matchId  
* winnerWrestlerId  
* loserWrestlerId  
* winnerCompetitorSnapshotId  
* loserCompetitorSnapshotId  
* winnerSeed  
* loserSeed  
* winnerSchoolSnapshot  
* loserSchoolSnapshot  
* bracketSection  
* round  
* roundNumber  
* matchNumber  
* winnerScore  
* loserScore  
* victoryType  
* overtimeDetails  
* resultStatus  
* sourceType  
* sourceDocumentId  
* sourceReference  
* confidence  
* occurredAt  
* recordedAt  
* verifiedAt  
* correctedAt  
* version

The historical match record should preserve what happened in the match rather than relying entirely on the current state of the rendered bracket.

### **Result Versioning and Corrections**

Official results may be corrected after they are initially entered.

Never overwrite a historical result without retaining the previous version.

A correction should create a versioned result history containing:

* Previous value  
* Corrected value  
* Reason for correction  
* User who made the correction  
* Time of correction  
* Source supporting the correction  
* Fantasy scores affected  
* Leaderboards affected

The latest verified version should be treated as the current official result, while earlier versions remain available for audit and reproducibility.

### **Data Provenance**

Every imported or manually entered result should retain information about where it came from.

Possible source types include:

* Uploaded tournament PDF  
* Manually entered result  
* Tournament-provider import  
* Official results feed  
* Administrator correction  
* Verified external source

Store:

* Source type  
* Source document  
* Source URL, when permitted  
* Import timestamp  
* Importing user or service  
* Parser version  
* Original extracted value  
* Extraction confidence  
* Verification status  
* Verifying administrator

The platform should distinguish between:

* Imported  
* Unverified  
* Administrator reviewed  
* Verified  
* Disputed  
* Corrected

Future predictive models should be able to exclude unverified or low-confidence data.

### **Prediction-Ready Features**

Where available, retain structured variables that may later be useful as model features.

Examples include:

* Wrestler seed  
* Opponent seed  
* Weight class  
* Tournament level  
* Tournament size  
* Bracket round  
* Championship or consolation bracket  
* Prior head-to-head record  
* Prior season record  
* Recent win percentage  
* Victory-type history  
* Average point differential  
* School  
* Year in school  
* Days since previous match  
* Previous tournament placement  
* Historical performance against comparable seeds  
* Fantasy pick percentage  
* Public prediction consensus

Do not calculate or fabricate unavailable values. Store raw historical facts first and derive model features through a separate analytics pipeline.

### **Separation of Raw Data and Derived Data**

Maintain a clear distinction between:

1. Raw source data  
2. Administrator-approved official data  
3. Derived statistics  
4. Predictive model features  
5. Model-generated predictions

Raw and approved official data should remain stable and auditable.

Derived statistics and predictions must be reproducible from a known:

* Dataset version  
* Feature pipeline version  
* Model version  
* Calculation timestamp  
* Configuration

Do not store model predictions as though they were official match results.

### **Dataset Snapshots**

Support versioned dataset snapshots for model development and backtesting.

A dataset snapshot should record:

* Snapshot ID  
* Creation timestamp  
* Included tournaments  
* Included seasons  
* Data-quality filters  
* Result versions  
* Feature-pipeline version  
* Excluded records  
* Schema version

This will allow future models to be trained and evaluated against a stable dataset even as new tournaments and corrections are added.

### **Preventing Data Leakage**

Future predictive systems must only use information that would have been available before the match being predicted.

For example, a historical model predicting a match from March 1 must not use:

* Results entered after March 1  
* Final tournament placement  
* Later-season statistics  
* Future rankings  
* Fantasy consensus collected after the prediction deadline

All relevant records should include reliable timestamps so training datasets can be constructed as point-in-time datasets.

### **Historical Analytics**

Provide a future-facing data layer capable of answering questions such as:

* How often does each seed defeat another seed?  
* How often does each seed reach each placement?  
* Which wrestlers consistently outperform their seeds?  
* Which schools perform best by weight class?  
* Which victory types are most common by round?  
* Which wrestlers have faced each other previously?  
* How accurate are fantasy players compared with consensus picks?  
* Which users are strongest at predicting specific weights or rounds?  
* Which upset patterns occur most frequently?  
* How well would a predictive model have performed on past tournaments?

### **Data Export**

Administrators should eventually be able to export authorized historical data in formats such as:

* CSV  
* JSON  
* Parquet

Exports should support filters for:

* Date range  
* Season  
* Tournament  
* Weight class  
* Wrestler  
* School  
* Bracket round  
* Victory type  
* Verification status

Exports must respect privacy, licensing, and data-access permissions.

### **Retention and Deletion Policy**

Tournament results and match records should be retained permanently unless removal is legally required.

User fantasy entries may require a separate privacy and account-deletion policy.

When a user deletes an account:

* Remove or anonymize personal profile information as required.  
* Preserve anonymized fantasy and prediction records where legally permitted.  
* Preserve official tournament and match results.  
* Do not remove shared historical competition data solely because a fantasy user deletes an account.

### **Additional Domain Entities**

Add entities similar to the following.

#### **Wrestler**

* id  
* canonicalName  
* normalizedName  
* currentSchoolId  
* externalIdentifiers  
* profileStatus  
* createdAt  
* updatedAt

#### **CompetitorSnapshot**

* id  
* tournamentId  
* competitorId  
* wrestlerId  
* displayedName  
* normalizedName  
* schoolName  
* seed  
* weightClass  
* recordAtTournament  
* metadata  
* createdAt

#### **HistoricalMatchResult**

* id  
* tournamentId  
* matchId  
* resultVersion  
* winnerWrestlerId  
* loserWrestlerId  
* winnerSnapshotId  
* loserSnapshotId  
* winnerScore  
* loserScore  
* victoryType  
* bracketSection  
* round  
* resultStatus  
* sourceId  
* occurredAt  
* verifiedAt  
* supersededById  
* createdAt

#### **ResultSource**

* id  
* sourceType  
* uploadedDocumentId  
* sourceReference  
* parserName  
* parserVersion  
* importedBy  
* importedAt  
* verificationStatus  
* confidence  
* metadata

#### **WrestlerIdentityLink**

* id  
* competitorId  
* wrestlerId  
* confidence  
* matchMethod  
* status  
* reviewedBy  
* reviewedAt

#### **DatasetSnapshot**

* id  
* name  
* schemaVersion  
* featurePipelineVersion  
* filterConfiguration  
* tournamentCutoffDate  
* recordCount  
* storageLocation  
* createdAt

#### **ModelPrediction**

This entity can be introduced later.

* id  
* modelVersionId  
* datasetSnapshotId  
* tournamentId  
* matchId  
* predictedWinnerId  
* predictedWinnerProbability  
* alternativeOutcomeProbability  
* generatedAt  
* informationCutoffAt  
* featureSnapshot  
* actualOutcome  
* evaluationMetrics

### **Revised MVP Requirement**

The MVP does not need to train or operate a prediction model.

However, the MVP must:

* Permanently retain completed tournament results.  
* Preserve all match-level outcomes.  
* Preserve tournament and competitor snapshots.  
* Record result sources and verification status.  
* Version corrected results.  
* Use stable wrestler and tournament identifiers.  
* Avoid destructive deletion of archived tournaments.  
* Preserve scoring configurations used by historical fantasy entries.  
* Preserve submitted fantasy predictions after tournaments finish.  
* Include timestamps needed for future point-in-time analysis.  
* Provide an internal structured export of historical tournament data.

### **Future Prediction Phase**

After enough verified tournament data has been collected, implement a separate prediction and data-science phase.

That phase may include:

1. Identity resolution across tournaments  
2. Historical data cleanup  
3. Feature engineering  
4. Wrestler rating systems  
5. Baseline prediction models  
6. Probability calibration  
7. Historical backtesting  
8. Model comparison  
9. Prediction APIs  
10. User-facing predictive insights  
11. Model monitoring  
12. Retraining workflows

Initial baseline models should be compared against simple benchmarks such as:

* Higher seed always wins  
* Better historical win percentage wins  
* Consensus fantasy pick wins  
* Elo-style wrestler rating  
* Historical seed-matchup frequency

The system should not display model probabilities as authoritative facts. Predictions should be presented as estimates with model version, update time, and appropriate uncertainty.

## **External Results Ingestion, Automated Updates, and Historical Backfills**

The administrator area must support both manual result entry and automated collection of tournament results from authorized external sources.

The goal is to reduce the amount of repetitive manual data entry while preserving accuracy, provenance, auditability, and administrative control.

The system should support two related workflows:

1. Continuously checking external tournament-result sources for new live results.  
2. Importing historical tournament and wrestler results for long-term analytics and future predictive modeling.

Automated ingestion must never bypass the platform’s validation, identity-resolution, provenance, and correction systems.

## **1\. Administrator Results Center**

Create a dedicated **Results Ingestion** area within the tournament administration interface.

This area should contain:

* Manual result entry  
* External source configuration  
* Live ingestion status  
* Imported-result review queue  
* Data conflicts  
* Unmatched wrestlers  
* Unmatched tournaments  
* Historical backfill jobs  
* Source health monitoring  
* Import history  
* Parser logs  
* Result correction history  
* Data-quality reports

Administrators should be able to see which results were:

* Entered manually  
* Extracted from an uploaded PDF  
* Imported from an external page  
* Retrieved through an official API  
* Suggested by an AI-assisted extraction process  
* Automatically accepted  
* Manually verified  
* Rejected  
* Corrected after import

## **2\. Manual Result Entry**

Manual entry must remain available even when automated ingestion is enabled.

Administrators should be able to:

* Select the tournament  
* Select the weight class  
* Select the match  
* Choose the winner and loser  
* Enter the score  
* Select the victory type  
* Enter the match time, when available  
* Add notes  
* Attach or reference a source  
* Mark the result as verified  
* Correct a previously entered result

The interface should be optimized for rapid entry.

Helpful functionality may include:

* Keyboard navigation  
* Bulk entry  
* Automatic winner advancement  
* Automatic match lookup  
* Recent-wrestler suggestions  
* Validation against the bracket  
* Duplicate-result warnings  
* Conflict warnings  
* Undo for unsaved changes  
* A queue of unresolved matches

Manual results and automated results must use the same underlying result-processing and scoring pipeline.

## **3\. External Source Configuration**

Administrators should be able to configure one or more external result sources for a tournament.

A source configuration may include:

* Source name  
* Source type  
* Base URL  
* Tournament URL  
* Bracket URL  
* Results URL  
* Weight-class-specific URLs  
* Authentication configuration, when authorized  
* Request headers, when permitted  
* Parser or adapter  
* Update frequency  
* Source priority  
* Enabled or disabled status  
* Automatic-approval policy  
* Last successful check  
* Last detected change  
* Last error  
* Verification requirements

Supported source types may eventually include:

* Official tournament APIs  
* Public results APIs  
* Structured data feeds  
* HTML result pages  
* Online brackets  
* Publicly available PDF brackets  
* Publicly available PDF result reports  
* CSV exports  
* JSON exports  
* XML feeds  
* Authorized third-party integrations  
* Manually uploaded files

Prefer official APIs, feeds, or licensed data partnerships whenever they are available.

## **4\. Source Adapter Architecture**

Implement external collection through a source-adapter interface rather than embedding website-specific logic throughout the application.

A conceptual adapter may resemble:

interface ResultsSourceAdapter {  
  sourceType: string;

  canHandle(config: ResultsSourceConfig): Promise\<boolean\>;

  discover(config: ResultsSourceConfig): Promise\<DiscoveredResource\[\]\>;

  fetch(  
    config: ResultsSourceConfig,  
    checkpoint?: SourceCheckpoint  
  ): Promise\<SourceFetchResult\>;

  parse(  
    fetchResult: SourceFetchResult  
  ): Promise\<ParsedExternalResult\[\]\>;

  normalize(  
    parsedResults: ParsedExternalResult\[\],  
    context: TournamentContext  
  ): Promise\<NormalizedResultCandidate\[\]\>;

  getNextCheckpoint(  
    fetchResult: SourceFetchResult  
  ): Promise\<SourceCheckpoint\>;  
}

Each provider-specific adapter should be independently testable and versioned.

The platform should support:

* Provider-specific adapters  
* Generic HTML extraction  
* Generic PDF extraction  
* Structured-data extraction  
* AI-assisted extraction  
* Manual mapping templates  
* Future API integrations

A provider-specific adapter should be preferred over generic AI extraction when a source has a stable known structure.

## **5\. Scheduled Live Result Collection**

Allow administrators to schedule recurring source checks for active tournaments.

Suggested configurable intervals include:

* Every 15 minutes  
* Every 30 minutes  
* Hourly  
* Every two hours  
* Custom intervals within platform limits  
* Manual refresh only

A default active-tournament interval may be every 15 minutes.

The schedule may change according to tournament state:

* Before the tournament: low-frequency checks  
* During active competition: frequent checks  
* After tournament completion: one or more verification checks  
* After archival: scheduled checking disabled

The scheduler should create background ingestion jobs rather than performing scraping inside a user request.

Each scheduled run should:

1. Load enabled source configurations.  
2. Check whether the source has changed.  
3. Retrieve only necessary content when possible.  
4. Parse new or modified results.  
5. Normalize names, rounds, scores, and victory types.  
6. Match the external tournament to an internal tournament.  
7. Match external competitors to internal competitors.  
8. Match external results to internal matches.  
9. Detect duplicates and conflicts.  
10. Store result candidates.  
11. Apply safe results according to the configured approval policy.  
12. Send uncertain results to the review queue.  
13. Recalculate predictions and leaderboards for approved results.  
14. Save the source checkpoint.  
15. Record metrics, errors, and audit events.

## **6\. Incremental Fetching and Change Detection**

Avoid repeatedly downloading and reprocessing complete result sites when no changes have occurred.

Where supported, use:

* HTTP cache headers  
* ETags  
* Last-Modified values  
* Content checksums  
* Page hashes  
* Provider timestamps  
* Incremental APIs  
* Pagination cursors  
* Source checkpoints  
* Match-level change detection

Store a checkpoint for every source so the system knows what was previously processed.

Suggested checkpoint fields include:

* sourceConfigId  
* lastCheckedAt  
* lastSuccessfulFetchAt  
* lastModifiedValue  
* etag  
* contentHash  
* providerCursor  
* latestObservedResultTimestamp  
* latestObservedMatchIdentifier  
* parserVersion  
* errorCount

## **7\. Result Candidate Workflow**

External data should first become a result candidate rather than immediately becoming an official result in all circumstances.

A result candidate should contain:

* Source configuration  
* Source URL or resource identifier  
* Source tournament name  
* Source weight class  
* Source match identifier  
* Source round  
* Source wrestler names  
* Source school names  
* Source seeds  
* Winner  
* Loser  
* Score  
* Victory type  
* Match time  
* Parsed timestamp  
* Extraction method  
* Parser version  
* Match confidence  
* Wrestler identity confidence  
* Tournament identity confidence  
* Overall confidence  
* Raw source fragment  
* Import status

Possible candidate states:

* Detected  
* Parsed  
* Normalized  
* Matched  
* Needs review  
* Approved  
* Automatically approved  
* Rejected  
* Superseded  
* Conflict  
* Failed

Only approved candidates should update official tournament results.

## **8\. Automatic Approval Rules**

Allow controlled automatic approval for high-confidence results.

An administrator may configure policies such as:

* Never automatically approve  
* Automatically approve results from an official API  
* Automatically approve results above a confidence threshold  
* Automatically approve only when the internal bracket match is unambiguous  
* Automatically approve only completed matches  
* Automatically approve only when two independent sources agree  
* Require review for forfeits or unusual outcomes  
* Require review when a result changes an existing official result  
* Require review when wrestler identity confidence is below a threshold

A result should not be automatically approved when:

* Multiple internal matches could correspond to it  
* Wrestler identity is uncertain  
* The imported result conflicts with an existing verified result  
* The score is structurally invalid  
* The winner is not a participant in the matched internal match  
* The result would create an impossible bracket state  
* The source is unverified  
* The source format has unexpectedly changed  
* The parser version is in a degraded state  
* The result appears to be a duplicate with different details

## **9\. Administrative Review Queue**

Create a review interface for ambiguous or conflicting results.

For each candidate, show:

* Imported result  
* Matched internal match  
* Source excerpt or page region  
* Source link, when appropriate  
* Parser confidence  
* Identity-match confidence  
* Existing official result  
* Bracket implications  
* Fantasy scoring implications  
* Suggested action

Administrative actions should include:

* Approve  
* Reject  
* Edit and approve  
* Match to another internal match  
* Link to another wrestler  
* Create a new wrestler  
* Merge wrestler identities  
* Mark source as unreliable  
* Reprocess with another parser  
* Defer  
* Flag for another administrator

Bulk approval should be available only for results that satisfy strict validation rules.

## **10\. Conflict Resolution**

The system must detect conflicts between:

* Two external sources  
* External and manual results  
* Two versions of the same external page  
* Imported results and verified results  
* Bracket progression and imported results  
* Wrestler identities  
* Match numbers  
* Victory types  
* Scores

Do not silently overwrite an existing verified result.

When a conflict occurs:

1. Preserve both values.  
2. Record both sources.  
3. Identify the currently official result.  
4. Mark the candidate as a conflict.  
5. Pause automatic application for affected dependent matches where needed.  
6. Notify an administrator.  
7. Record the final decision and reason.  
8. Recalculate fantasy scores if the official result changes.

Source priority may help with review, but it should not automatically override a verified result unless explicitly configured.

## **11\. Source Priority and Consensus**

Allow administrators to rank configured sources.

An example priority order might be:

1. Official tournament API  
2. Official tournament website  
3. Official bracket provider  
4. Verified tournament document  
5. Trusted third-party results provider  
6. Public results page  
7. AI-assisted extraction from an unstructured page

The system may compute consensus when multiple independent sources report the same result.

Store:

* Number of agreeing sources  
* Number of disagreeing sources  
* Highest-priority supporting source  
* Latest observation  
* Earliest observation  
* Confidence based on source agreement

Do not treat several pages that copy the same upstream source as fully independent evidence when that relationship is known.

## **12\. Historical Backfill Workspace**

Create a separate workflow for collecting historical tournament and wrestler data.

Administrators should be able to define a backfill project with:

* Project name  
* Target organization  
* Target season or date range  
* Target tournaments  
* Starting URLs  
* Allowed domains  
* Source types  
* Crawl depth  
* Page limit  
* Rate limit  
* Data fields sought  
* Parser strategy  
* Review requirements  
* Storage limits  
* Priority  
* Status

The administrator may provide one or more authorized starting locations, such as:

* Tournament archive pages  
* Season index pages  
* Wrestler profile pages  
* Historical bracket pages  
* Result-report directories  
* Public PDF archives  
* Official team schedules  
* Official tournament-provider archives

The system should discover relevant pages and documents within the configured scope.

## **13\. AI-Assisted Historical Discovery**

Use AI as an extraction and classification assistant, not as an unrestricted autonomous web crawler.

AI-assisted functionality may include:

* Determining whether a page contains wrestling results  
* Identifying tournament names and dates  
* Identifying weight classes  
* Extracting match results  
* Extracting wrestler histories  
* Locating links to bracket PDFs  
* Mapping page fields into the internal schema  
* Suggesting wrestler identity matches  
* Detecting duplicate tournaments  
* Identifying missing rounds  
* Recommending follow-up pages  
* Explaining low-confidence imports

The system must limit AI access to administrator-approved sources and domains.

AI output should be treated as a proposed structured record until it passes deterministic validation and any required human review.

Do not allow an AI process to invent missing results. Unknown fields must remain unknown.

## **14\. Historical Crawl and Discovery Jobs**

A historical backfill job may follow this process:

1. Load approved seed URLs and domains.  
2. Retrieve the starting resources.  
3. Classify each page or document.  
4. Extract links relevant to tournaments, brackets, wrestlers, or results.  
5. Add permitted links to a bounded discovery queue.  
6. Prevent duplicate retrieval.  
7. Fetch resources according to rate limits.  
8. Save raw source artifacts when permitted.  
9. Extract structured tournament and match candidates.  
10. Normalize tournament names, dates, schools, and wrestlers.  
11. Match records against existing platform data.  
12. Detect duplicates and conflicts.  
13. Place uncertain records into review queues.  
14. Approve or reject imports.  
15. Create permanent historical records.  
16. Produce a backfill-completion and data-quality report.

Backfill jobs must be resumable.

A failed job should continue from its last checkpoint rather than starting over.

## **15\. Crawl Boundaries and Safety Controls**

Every discovery or scraping job must have explicit boundaries.

Required controls include:

* Allowed domains  
* Denied domains  
* Maximum page count  
* Maximum crawl depth  
* Maximum file size  
* Maximum total storage  
* Request interval  
* Concurrent request limit  
* Job expiration  
* Approved content types  
* Redirect restrictions  
* Authentication restrictions  
* Manual stop control  
* Emergency disable switch

The system should not blindly follow every discovered link.

Avoid crawling:

* Account pages  
* Login forms  
* Shopping pages  
* Advertising links  
* Unrelated social-media pages  
* Calendar exports unrelated to results  
* Infinite pagination loops  
* Search-result loops  
* Duplicate URL variants  
* User-specific pages  
* Private or access-controlled content without authorization

## **16\. Legal, Contractual, and Ethical Requirements**

External data collection must be implemented responsibly.

Before enabling a source, the platform should consider:

* Website terms of use  
* API terms  
* Data licenses  
* Copyright restrictions  
* Database rights  
* Robots directives  
* Authentication requirements  
* Rate limits  
* Personal-information considerations  
* Restrictions on republication  
* Restrictions on commercial use  
* Restrictions on automated access

Prefer obtaining permission or using official integrations for important recurring sources.

Do not design the system to:

* Circumvent access controls  
* Bypass authentication  
* Evade technical restrictions  
* Defeat anti-bot protections  
* Rotate identities to avoid rate limits  
* Access private data without authorization  
* Ignore explicit removal requests  
* Republish protected content beyond permitted use

Store only the data and source artifacts the platform is authorized to retain.

When full source-page storage is not permitted, store structured facts, permitted excerpts, hashes, timestamps, and source references instead.

## **17\. Rate Limiting and Source Protection**

The ingestion system must minimize load on external services.

Use:

* Configurable request delays  
* Per-domain rate limits  
* Exponential backoff  
* Retry limits  
* Randomized scheduling within an approved interval  
* Caching  
* Conditional requests  
* Duplicate-request prevention  
* Circuit breakers  
* Source-specific concurrency limits

Repeated failures should automatically disable or pause a source.

Suggested source health states:

* Healthy  
* Delayed  
* Degraded  
* Parser failure  
* Authentication failure  
* Rate limited  
* Structure changed  
* Disabled  
* Under review

## **18\. Parser Change Detection**

External sites may change their HTML or document structure without notice.

The system should detect signals such as:

* Expected selectors missing  
* Unexpected decrease in result count  
* Unexpected increase in result count  
* Missing wrestler names  
* Invalid score formats  
* Unknown round names  
* Large confidence decrease  
* New page templates  
* CAPTCHA or block pages  
* Login redirects  
* Error-page content  
* Parser output with impossible bracket states

When a structural change is detected:

* Stop automatic approval for that source.  
* Mark the adapter as degraded.  
* Preserve the fetched content for debugging when permitted.  
* Notify administrators or developers.  
* Route extracted results to manual review.  
* Record the parser and page versions involved.

## **19\. Identity Resolution During Import**

Historical imports will frequently contain inconsistent wrestler and school names.

The ingestion system should normalize:

* Capitalization  
* Punctuation  
* Common abbreviations  
* Suffixes  
* School aliases  
* Diacritics  
* Middle initials  
* Name ordering  
* Weight-class formatting  
* Tournament naming variations

Identity matching may consider:

* Exact normalized name  
* School  
* Weight class  
* Season  
* Graduation year  
* Hometown  
* Opponent history  
* Existing external identifier  
* Known aliases  
* Tournament participation overlap

Possible identity states:

* Exact match  
* Probable match  
* Ambiguous  
* New identity  
* Duplicate candidate  
* Rejected match  
* Requires review

Never merge identities solely because two records have the same normalized name.

## **20\. Tournament Matching**

External tournament records must be matched to the correct internal tournament.

Matching factors may include:

* Tournament name  
* Date  
* Location  
* Host school  
* Organization  
* Season  
* Weight classes  
* Competitor list  
* Source identifier  
* Bracket-provider identifier

The system should detect when a discovered event is:

* A new tournament  
* Another source for an existing tournament  
* A different division of an existing event  
* A duplicate tournament record  
* A preliminary or qualifying event  
* A team dual rather than an individual bracket tournament  
* An unrelated event

Ambiguous tournament matches should require review.

## **21\. Historical Wrestler Performance Imports**

The backfill system should support collecting wrestler-level historical performance.

Potential records include:

* Tournament participation  
* Match history  
* Opponents  
* Wins and losses  
* Match scores  
* Victory types  
* Tournament placement  
* Weight class  
* School  
* Season record  
* Head-to-head history  
* Seed  
* Ranking, when the source permits storage  
* Awards or qualification status  
* Source and verification metadata

Distinguish between:

* Match-level facts  
* Tournament summaries  
* Season summaries  
* Rankings  
* Derived statistics

A season-summary record should not be treated as a replacement for match-level records when individual match data is available.

## **22\. Raw Source Archive**

Where legally and contractually permitted, retain raw source artifacts used during ingestion.

Examples include:

* HTML snapshots  
* JSON responses  
* XML responses  
* PDFs  
* CSV files  
* Screenshots of relevant source regions  
* Extracted text  
* Content hashes

Raw artifacts make it possible to:

* Re-run improved parsers  
* Investigate corrections  
* Validate data provenance  
* Compare page changes  
* Recover missed fields  
* Audit AI extraction  
* Rebuild historical datasets

Raw source artifacts should include retention, access-control, and deletion policies.

They must not be publicly exposed by default.

## **23\. Reprocessing**

Allow administrators to reprocess previously collected source artifacts using a newer parser or extraction model.

A reprocessing job should:

* Preserve the original parsed output  
* Record the new parser version  
* Produce new result candidates  
* Compare old and new output  
* Highlight changed fields  
* Avoid automatically replacing verified results  
* Preserve all previous import versions  
* Require review for material changes

This capability is important because extraction quality will improve over time.

## **24\. Observability and Monitoring**

Track ingestion metrics such as:

* Sources checked  
* Successful fetches  
* Failed fetches  
* Changed resources  
* Unchanged resources  
* Results detected  
* Results automatically approved  
* Results awaiting review  
* Conflicts  
* Duplicate results  
* Unmatched wrestlers  
* Unmatched tournaments  
* Parser confidence  
* Processing duration  
* Requests by domain  
* Rate-limit events  
* Source disablements  
* Scoring updates triggered

Provide an operational dashboard for administrators and developers.

## **25\. Suggested Additional Entities**

### **ResultsSourceConfig**

* id  
* tournamentId  
* name  
* sourceType  
* baseUrl  
* resultsUrl  
* adapterName  
* adapterVersion  
* updateInterval  
* sourcePriority  
* approvalPolicy  
* allowedDomains  
* configuration  
* enabled  
* lastCheckedAt  
* lastSuccessfulAt  
* healthStatus  
* createdBy  
* createdAt  
* updatedAt

### **SourceCheckpoint**

* id  
* sourceConfigId  
* etag  
* lastModified  
* contentHash  
* providerCursor  
* latestResultTimestamp  
* latestExternalMatchId  
* parserVersion  
* lastCheckedAt  
* metadata

### **SourceFetch**

* id  
* sourceConfigId  
* requestUrl  
* responseStatus  
* contentType  
* contentHash  
* storageLocation  
* fetchedAt  
* duration  
* parserVersion  
* fetchStatus  
* errorDetails

### **ExternalResultCandidate**

* id  
* sourceFetchId  
* sourceConfigId  
* tournamentId  
* externalTournamentIdentifier  
* externalMatchIdentifier  
* sourceWeightClass  
* sourceRound  
* sourceWinner  
* sourceLoser  
* sourceScore  
* sourceVictoryType  
* normalizedPayload  
* matchedMatchId  
* winnerCompetitorId  
* loserCompetitorId  
* extractionConfidence  
* matchConfidence  
* identityConfidence  
* overallConfidence  
* status  
* reviewedBy  
* reviewedAt  
* createdAt

### **IngestionConflict**

* id  
* tournamentId  
* matchId  
* candidateId  
* conflictType  
* existingValue  
* candidateValue  
* resolution  
* resolvedBy  
* resolvedAt  
* createdAt

### **BackfillProject**

* id  
* name  
* description  
* dateRangeStart  
* dateRangeEnd  
* allowedDomains  
* seedUrls  
* sourceTypes  
* targetFields  
* crawlConfiguration  
* reviewPolicy  
* status  
* createdBy  
* startedAt  
* completedAt  
* createdAt

### **BackfillJob**

* id  
* backfillProjectId  
* jobType  
* checkpoint  
* pagesDiscovered  
* pagesFetched  
* recordsExtracted  
* recordsApproved  
* errors  
* status  
* startedAt  
* completedAt

### **DiscoveredResource**

* id  
* backfillJobId  
* url  
* canonicalUrl  
* parentResourceId  
* depth  
* resourceType  
* classification  
* contentHash  
* fetchStatus  
* processingStatus  
* discoveredAt  
* processedAt

### **SourceAdapter**

* id  
* name  
* provider  
* version  
* supportedSourceTypes  
* status  
* configurationSchema  
* createdAt  
* updatedAt

## **26\. Background Job Types**

Create background jobs for:

* Scheduled source check  
* Source fetch  
* Resource classification  
* HTML parsing  
* PDF parsing  
* AI-assisted extraction  
* Result normalization  
* Tournament matching  
* Wrestler identity matching  
* Match matching  
* Candidate validation  
* Automatic approval  
* Result application  
* Score recalculation  
* Leaderboard recalculation  
* Historical resource discovery  
* Historical backfill  
* Raw-source reprocessing  
* Source health checks  
* Failed-job retry

Jobs should be:

* Idempotent  
* Retryable  
* Observable  
* Rate limited  
* Checkpointed  
* Auditable

A job retry must not create duplicate official results or award fantasy points twice.

## **27\. Security Requirements**

Treat imported external content as untrusted input.

Protect against:

* Malicious HTML  
* Malicious PDFs  
* Script execution  
* Server-side request forgery  
* Requests to internal networks  
* Unsafe redirects  
* Excessive file sizes  
* Compression bombs  
* Unexpected binary files  
* Parser exploits  
* Prompt injection contained in source pages  
* Malicious instructions embedded in documents  
* Credential leakage  
* Unauthorized source access

All fetching services should use network restrictions and URL validation.

AI extraction systems must treat webpage text as data, not as trusted instructions.

## **28\. Revised MVP Scope**

The first production release should include:

* Manual result entry  
* Source attribution for manual results  
* A source-configuration model  
* Scheduled background jobs  
* At least one provider-specific adapter or one controlled generic importer  
* External result candidates  
* Administrative review and approval  
* Duplicate detection  
* Conflict detection  
* Result provenance  
* Idempotent result application  
* Automatic score and leaderboard recalculation  
* Basic source-health monitoring  
* Manually initiated historical imports from approved URLs or files  
* Raw source retention when permitted

The MVP does not need to support unrestricted crawling of the public internet.

Start with a small number of known, authorized result sources and build adapters for those sources.

## **29\. Post-MVP Scope**

Later releases may add:

* Additional provider adapters  
* Official API partnerships  
* Multi-source consensus  
* Fully scheduled historical backfills  
* Bounded link discovery  
* AI-assisted page classification  
* AI-assisted parser generation  
* Wrestler profile discovery  
* Automated identity suggestions  
* Dataset-quality scoring  
* Parser self-testing  
* Large-scale reprocessing  
* Data licensing controls  
* Source-specific retention policies  
* Automated anomaly detection  
* Near-real-time event feeds

## **30\. Acceptance Criteria**

The automated results system is complete for an initial release when:

1. An administrator creates a tournament.  
2. The administrator configures an authorized external results source.  
3. A scheduled job checks the source at the configured interval.  
4. The system detects a newly posted match result.  
5. The system parses the competitors, winner, score, and victory type.  
6. The result is matched to the correct internal tournament match.  
7. A result candidate is created.  
8. A low-confidence candidate enters the review queue.  
9. An administrator approves the candidate.  
10. The official bracket updates.  
11. Fantasy scores and leaderboards recalculate.  
12. The result retains its source and import history.  
13. The same source is checked again without creating a duplicate result.  
14. A conflicting source result is detected and does not silently overwrite the verified result.  
15. An administrator creates a historical backfill project from approved source URLs.  
16. Historical matches are imported as reviewable candidates.  
17. Approved historical results are linked to canonical wrestlers where possible.  
18. Uncertain wrestler identities remain unresolved rather than being incorrectly merged.  
19. A failed job resumes from its last checkpoint.  
20. Every fetch, parse, approval, correction, and result application is auditable.

## **31\. Implementation Principle**

Automated collection should accelerate result entry, not weaken data integrity.

The ingestion system should follow this sequence:

**External source → raw artifact → parsed candidate → normalized candidate → identity matching → deterministic validation → administrator or policy approval → official result → fantasy scoring → permanent historical archive**

External pages, imported documents, and AI-generated extraction output are evidence. They are not automatically the source of truth.

The source of truth is the versioned, approved official result stored by the platform.

