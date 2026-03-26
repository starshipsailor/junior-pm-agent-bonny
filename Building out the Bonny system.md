
---
My prompt:

A previous session ran and completed about 60% of the plan before something went wrong and it died out. Now that you read the logs from that session - they're not fully accurate because the session died without writing logs and I had to recreate them manually. So there may be mistakes in those logs.  I need you to undertand and build Bonny for me. Here's the full prompt I had shared with the previous session for the V2 build. It managed to build the folder structure and populate all the people, projects and teams correctly before it stopped working.

Remember that the entire knowledege graph has been built with the intention of having live links across the pages. So it's easy to understand what links to what. Eg: Whereever a individual is mentioned, it should always be linked back to the original link page of that individual. Same for projects, teams etc. This is inspired from this article below - Write Once, surface everywhere

# Write Once, Surface Everywhere 

Here's the core idea:

You should never have to enter the same information twice.

When you create a meeting note, you add some basic info at the top such as date, attendees, which project it relates to. That's it.

From that moment, the note automatically shows up in:

- The project's page (under "Related Meetings")
    
- Your daily note (under "Today's Meetings")
    
- The person's profile if you track stakeholders
    
- Any dashboard that queries for meetings
    

You didn't link anything manually. You didn't copy and paste. The structure does the work.

Write once. Surface everywhere

[![r/ClaudeAI - Write once. Surface everywhere.](https://preview.redd.it/claude-code-obsidian-how-i-use-it-short-guide-v0-uf0u3augjggg1.gif?width=1440&auto=webp&s=40a17aa1e24c2464a8a7d96a776d9f3cf9e00872)](https://preview.redd.it/claude-code-obsidian-how-i-use-it-short-guide-v0-uf0u3augjggg1.gif?width=1440&auto=webp&s=40a17aa1e24c2464a8a7d96a776d9f3cf9e00872 "Image from r/ClaudeAI - Write once. Surface everywhere.")

Write once. Surface everywhere.

This is called a **"proactive vault"**. Instead of you organising information, the vault organises itself based on metadata you add once.

**The Three Layers**

The system has three layers:

- **Capture** - Where content lands first. Inbox folder, quick note, voice memos
    
- **Process** - Where content gets structured. Project folders, meeting notes with proper metadata
    
- **Surface** - Where the content appears when needed. Dashboard, projects hubs, search results
    

Most people only think about capture. They get content in, but never build the processing and surfacing layers. So their notes become a graveyard.
# Here's how Bonny should work

We should organise knowledge with 'teams' at the root. There should be a folder called Business Chapter,and within it, a folder each for each squad within it. within it squad folder for each team there's a folder. Within each team folder, there's 3 files and a folder: teamname_KPIs, teamname_people, folder: teamname_projects. Within teamname_projects, there's a teamname_projects_charter.md (this will be the highlevel objective of each project,a broad summary of timeline of delivery and status. Then there's multiple MD files each for one of the projects within the teamname_projects_charter file. These MD files will have regular udpates that get populated from slack, confluence and meeting notes from Notion. Everytime a KPI or a person is named here, it should be linked back to the kpi in teamname_kpi or individual teamname_people. Each Person across all the vault will have a md file called Personname_teamname/functionname.md and has the team name, link back to the team and also a few notes about my impression about them. this file is where bonny should populate all my 1:1s or any new context it learns from my conversations, slack, confluence.  Any new context should be added with a date stamp in the same page      

The global People/ folder should have Global_people_index.md and individual_people/ folder. The index file would be the table with the person name and key attributes like slack, team name with link, teamname_people.md file link, a summary notes filed and any other relevant details you think would be useful. And then the personname_teamname.md should live within the  individual_people/ folder


So when Bonny encounters a person on slack and what's to know who, it searches people.md finds them, links back to the root teamname_people to get more context. Same for projects, there should be a global proejct  index which links back to each project within teamname_projects. When bonny learns about a project in slack/conversations/confluence she goes back and searches about the projects in the global index, takes the link back to root folder and updates context there. 

Finally, bonny shouldn't be one single agent but more like a system of agents. We'll need a few different instances of Bonny with multiple sub-agents with dedicated skills as well as independant claude-code instances Bonny that run on Cron. i suspect we'll need a sub-agent who's job it is to 'add to vault' which means it would know exactly how to navigate the above structure and update information to the right location. Another sub-agent who 'reads from vault' who does the other way round when Bonny needs context on something. These mostly should be sub-agents that Bonny can call. 

Bonny the agent should have 3 more independant claude code sessions each monitoring slack, confluence and meeting notes. They each would distill the essence of what they learn to Bonny who would then use the 'read-from-vault' agent to pull more context figure out what's happening and then call the 'write-to-vault' agent to update the knowledge graph. **Remember that each of the monitors should have some context about what they are reading. eg: Slack monitor should know what message it read and how to summarise it else it will be very lossy compression. Same goes for the other two.

The slack-monitor scans slack every 30 mins, captures every message in the last 30 mins that meets one of 3 criteria: 1. all DMs 2. Message that i'm tagged in or part of a thread I'm tagged in 3. Messages in a channel that I've listed in 'Priority' or 'Priority 2' sections. Slack-monitor will then go and read Global_people_index.md and project associated with the particular thread so have sufficient context to summarise the message in the right file under mission control. It uses the slack mcp to connect to slack. 

Confluence-monitor scans every 1 hour (15 mins offset from Slack-monitor) and reads every confluence page that I have recent read or edited or have been tagged on or have commented on in the last hour. It captures the link of the page for reference and summarises the relevant information from the page for Bonny on mission control docs. Confluence-monitor also first reads context before summarising so it knows what it's doing. And uses the Attlasian MCP to read confluence.

Meeting-notes-monitor scans every 1 hour (20mins offset from Slack-monitor). It reads meeting-notes from the Notion DB to find the meetings done in the last hour. It would take both the meeting raw transcript from Notion and also Notion's summary. It would then read necessary context from the knowledege graph to understand what the meeting is about and write relevant information in the docs within mission folder for Bonny to process. It would use the notion mcp and also find a way to scan my google calendar (either mcp or apple cal where my google cal is also synced) to find out who the participants were for the said meeting and use that to inform it's summary. Once processed, mark the checkbox field in the database as 'ticked' so you know it's been done.

Bonny runs once every 30 mins (at 10 mins offset to Slack-monitor) and reads the relevant folders under mission control. Understands all the changes that have happened in the last half an hour and then based on the operating-guidelines.md (This will be a set of principles. **You bootstrap the first version, and I'll edit from there.**) it decides which course of action to take. A single input may result in multiple actions or none at all. 

Actions Bonny can take:
1. draft a slack msg
2. write up a confluence page 
3. write a md file in vault
4. Update my Running Tasklist
5. organise my calendar

Each of these action should have a corresponding skill that explains bonny how to do it. Please create version 1 of the skill and I can edit. 

Then there also needs to be a 'bonny-self-improvement-loop' agent who would learn from everything that I am doing on top of the base action that bonny takes. Eg, if bonny writes a slack draft, I go and edit it, then the self improvmement    
loop subagent needs to capture that, understand what went wrong and then go update the relevant skill or the operating-guideline or bonny's role/memory.md to make sure she learns for the next time. The loop agent should diffs what Bonny drafted vs what I sent/committed. We can make this much more nuanced though. let there be a db or a file where every action bonny takes (slack draft, confluence etc) is captured with a task id. his can house within a Outputs & self-improvements folder at root. The self-improvement loop diffs sent vs this db/log/file. And then it can also interrogate me on why to undertsand the essence. To ask me questions, it should write to me on slack as a DM and I will reply in thread.  

Part of the reason why so many sub-agents and a system of agents architecture is context overload. Each instance can operate with 1M tokens and given the volume of information, it can quite be overwhelmed. We'll need to be systmic to avoid that.                                                                                                        
all of the above is my thinking. Feel free to ask question, point holes, make it tighter. Act as a black belt system architect at a Google equivalent and help me me build a resilient bonny system for my personal use at Wise.



---


  **Questions & holes to tighten**

  **1. Folder structure — depth vs. navigability**                    

  

  Your proposed structure is ~5 levels deep:

  Business Chapter/

    Acquiring Squad/

      Acquiring Platform/

        acquiring-platform_projects/

          acquiring-platform_projects_charter.md

          payfac-expansion.md                   

  That's a lot of nesting. Obsidian handles deep folders fine, but **wikilinks break if two files share a name** across

  different team folders (e.g., two teams both have a kpis.md). Your teamname_ prefix solves this — just confirming

  that's intentional and you're okay with the verbosity?                                                        

  **2. Person files — where do they live?**                                                                                  

  You said Personname_teamname.md — but where in the tree? Options:

  - **A)** Inside each team folder (e.g., BAX/bax_people/Margaret_BAM.md) — but then cross-team people are awkward

  - **B)** A global People/ folder at root with Personname_teamname.md — cleaner, and teamname_people.md just links into it  

  - **C)** Inside the team folder they belong to, with symlinks or redirects for cross-team visibility

  Which do you prefer? I'd lean **B** — single source of truth per person, team files just reference them.

  Yea, B makes sense. But I think what needs to happen is the global People/ folder should have Global_people_index.md and individual_people/ folder. The index file would be the table with the person name and key attributes like slack, team name with link, teamname_people.md file link, a summary notes filed and any other relevant details you think would be useful. And then the personname_teamname.md should live within the  individual_people/ folder

  **3.** **People** **outside** **your** **chapter**

  

  You interact with ~100 people. Many aren't in your chapter (PeopleOps, Finance, Kristo, etc.). They don't have a team  

  folder. Do they just live in the global People/ folder without a team backlink?

  **4. Projects that span teams**                                     

  

  Some projects (e.g., wise-business-strategy, biz-hiring-pipeline, kpi-tree-goal-setting) aren't owned by one team —

  they span the chapter. Where do these live? Options:

  - **A)** A Business Chapter/chapter_projects/ folder for cross-cutting projects

  - **B)** Assigned to whichever team is primary owner, with links from others   

  **5. Sub-agent architecture — runtime question**

  You described 6+ agents:

  - **Bonny** (orchestrator)                                                                                                 

  - **vault-reader** (context retrieval)                              

  - **vault-writer** (knowledge graph updates)

  - **slack-monitor**

  - **confluence-monitor**

  - **meeting-notes-monitor**

  - **self-improvement-loop**

  

  Are you envisioning these as:

  - **A)** Separate Claude Code processes running concurrently (e.g., cron jobs, background tasks)?

  - **B)** Sub-agents that Bonny spawns on-demand within a single session?                         

  - **C)** A mix — monitors run on schedule, vault-reader/writer are on-demand?

  This matters a lot for implementation. Option C seems most practical — monitors as cron/scheduled tasks that write to

  an inbox, Bonny processes the inbox when invoked.                                                                      

  **6. Operating guidelines — how prescriptive?**                                                                            

  When you say "operating guideline for each action" — are you thinking:

  - Decision tree style? ("IF project update AND status changed THEN update charter AND draft Slack to stakeholders")

  - Or more like principles? ("When a project status changes, ensure all stakeholders are informed")                 

  The former is more reliable but brittle; the latter is flexible but might make surprising choices.

  **7. Self-improvement loop — feedback capture**

  How does the self-improvement agent know you edited a Slack draft? Options:

  - It diffs what Bonny drafted vs. what you actually sent (requires Slack read-back)

  - You explicitly tell it ("I changed X because Y")

  - It monitors your Slack sends and compares to recent drafts

  

  The first is most automated but needs careful Slack API access. What's your preference?

---
1. yea, I'm fine with the folder verbosity. infact's it's necessary.                                                   

2. Yea, B makes sense. But I think what needs to happen is the global People/ folder should have Global_people_index.md  

and individual_people/ folder. The index file would be the table with the person name and key attributes like slack,     

team name with link, teamname_people.md file link, a summary notes filed and any other relevant details you think would  

be useful. And then the personname_teamname.md should live within the  individual_people/ folder                         

3. yep, in the global people as above without backlinks. But overtime the structure should evolve as new information is  

learnt or people change teams or new teams are formed. Which agent will do that? or is it a separate one?                

4. Option A. Projects that exist outside traditional team remit or at the chapter level shuold live there.               

5. Option c. Monitors are probably indiependant claude instances that run on schedule and Bonny may occasionally also    

spawn them. The read-write agents are probably more of subagents that Bonny spawns. The inbox idea also has merit. needs 

 to be more fleshed. Maybe a mission control for what each agent has done and handoff for next one in line               

6. more like principles                                                                                                  

7. Option a. It diffs what Bonny drafted vs what I sent. we can make this much more nuanced though. let there be a db or 

 a file where every action bonny takes (slack draft, confluence etc) is captured with a task id. The self-improvement    

loop diffs sent vs this db/log/file. And then it can also interrogate me on why to undertsand the essence. maybe it      

writes to me on some interface or writes to a file with questions and what it surmised from my edits. And I can go       

comment on it. This can house within a Outputs & self-improvements folder at root


---
1. business-plans-subscriptions → Biz Plans & Pricing team - yes

 2. accounting-integrations → AIR team  - yes                                                                                 

 3. launchpad-onboarding → BizOn team - yes

 4. free-plan → Biz Plans & Pricing team  - yes

 5. acquiring-payfac → Acquiring Platform team - yes                                                                     

 6. invoicing-2026 → Acquiring Platform / Getpaid Formats - yes

 7. file-exports → AIR team  - yes                                                                                            
 8. nbb-qa-mua-experience → BAM team   - yes

 9. multiple-account-details → BAX team - no. this is ADX (account details experience team which sits outside the Biz chapter)

 10. monite-integration → AIR team (or chapter-level) - chapter level.

 11. business-switcher-cashback → BizOn team - not yet a project. it's an opportunity for BizOn

 12. br-verification → chapter-level (external dependency) - ignore this.                                                              

 13. relevance-study → chapter-level (cross-cutting research) - yes. this is a mini project

 14. google-a2p → chapter-level (exploration) - yes, opportunity

 15. account-details-accessibility → BAX team - ADX team

 16. business-economics → Biz Plans & Pricing team - Yes. Part of the subscription workstream

  

 **NOT projects — should become chapter-level docs:**

 17. wise-business-strategy → chapter_strategy.md (reference doc) - yes

 18. kpi-tree-goal-setting → chapter_kpis.md (framework) - yes

 19. business-chapter-ceremonies → chapter_ceremonies.md (operations) - yes

 20. biz-hiring-pipeline → chapter_hiring.md (operations) - yes

 21. q2-planning-update → ephemeral, archive or fold into ceremonies - yes, ephemeral. ignore.

 22. acquiring-squad-structure → fold into Acquiring Squad metadata - yes

 23. bax-squad-formation → fold into BAS squad metadata - yes

 24. biz-onboarding-squad → fold into BizOn team metadata - yes.

 25. account-payable-biz-kyc → fold into AP virtual squad metadata - ignore.


introduce a page called opportunities which is a table with a name for opportunity, description, team it belongs to and a short description, and a firmness indicator. this can live at root folder

Also introduce a page called mini-projects in the chapter level projects. Here we can club all projects that are not quite a project but a small tiny thing.