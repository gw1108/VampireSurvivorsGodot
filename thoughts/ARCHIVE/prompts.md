Use firecrawl to extract text from https://en.wikipedia.org/wiki/Snake_(video_game_genre) . We are only interested in the text describing the game, gameplay, visuals, art, and game mechanics. Anything about the history, dates, genre, sequels, later games, name of video games, legacy, references, external links, or wikipedia metadata are not necessary. The goal is to get a rough game idea outline but for now we just want the relevant text from this website.

Read the snake-gameplay-extracted.md file and create a very simple product requirement document based off of that file. The goal is to describe a simple 2D game that will be implemented in godot. It should be 2D. If it's not clear what features should be in the final game work back and forth with me by asking clarifying questions before writing out the new snake-prd.md.

Move the prd to the correct place that taskmaster expects it to be.

(that moved it to .taskmaster/docs/prd.txt)

(At this point i thought the thing it created kinda sucks. Reworking and rerunning the prompt, but commiting this for posterity.)

Read the snake-gameplay-extracted.md file and create a very simple product requirement document based off of that file while also following the .taskmaster\templates\example_prd.txt template. The goal is to describe a simple 2D game that will be implemented in godot. It should be 2D. If it's not clear what features should be in the final game work back and forth with me by asking clarifying questions before writing out the new prd. Save out the prd into .taskmaster/docs/prd.txt.

(then I just directly ran task-master parse or some shit. Then task-master loop --verbose. But godot wasn't on the path so it fucked up. After fixing the compiler error and one time setup it works. Jank AF visuals though. Looking at the task-master source code, I'm not that happy with how it splits up the tasks. It seems to just yolo guess 10 every time which the LLM follows. Going to have to make changes to task-master.)

(trying again 5/16/2026 6:38PM)

Read the .firecrawl/snake-gameplay-extracted.md file and create a very simple product requirement document based off of that file into .taskmaster/docs/prd.txt. The goal is to describe a simple 2D game that will be implemented in godot. It should be 2D. If the feature or task requires art split the task into code-implementation-task and a art-implementation-task. For art-implementation-tasks use claude + pixellab mcp and generate the necessary assets that will be used by the code-implementation-task. If it's not clear what features should be in the final game work back and forth with me by asking clarifying questions before writing out the prd.

(It edited the readme which I did not want. Make sure to primarily edit the godot project C:\GameDev\SnakeGodotTaskmaster\snaketaskmaster . Do not edit any readmes.)

Read the .firecrawl/snake-gameplay-extracted.md file and create a very simple product requirement document based off of that file into .taskmaster/docs/prd.txt. The goal is to describe a simple 2D game that will be implemented in godot. It should be 2D. Tag the feature or task with art, code, or audio depending on if it requires art, code, or audio. If it requires more than one of these split the task into so that each task only requires one tag. For art tagged tasks find the appropriate art asset in source/sprites. For audio tagged tasks find the appropriate audio asset in source/audio. If it's not clear what features should be in the final game work back and forth with me by asking clarifying questions before writing out the prd.

(Trying again with a new prompt. For now going to combine and tell it to make clear that copying and finding audio files is all one task.:)

Read the .firecrawl/snake-gameplay-extracted.md file and create a very simple product requirement document based off of that file into .taskmaster/docs/prd.txt. The goal is to describe a simple 2D game that will be implemented in godot. It should be 2D. Tag the feature or task with art, code, or audio depending on if it requires art, code, or audio. If it requires more than one of these split the task into so that each task only requires one tag. For art tagged tasks find the appropriate art asset in source/sprites. For audio tagged tasks find the appropriate audio asset in source/audio. If it's not clear what features should be in the final game work back and forth with me by asking clarifying questions before writing out the prd.

(results: The snake game didn't copy and paste the art assets from source. In the future, will have to copy and paste them to the correct spot from the start probably.)

Read the .firecrawl/snake-gameplay-extracted.md file and create a very simple product requirement document based off of that file into .taskmaster/docs/prd.txt. The goal is to describe a simple 2D game that will be implemented in godot. It should be 2D. Tag the feature or task with art, code, or audio depending on if it requires art, code, or audio. If it requires more than one of these split the task into so that each task only requires one tag. For art tagged tasks find the appropriate art asset in sprites folder which should already be setup. For audio tagged tasks find the appropriate audio asset in audio. If it's not clear what features should be in the final game work back and forth with me by asking clarifying questions before writing out the prd.

(Gonna try architect prompt => from architect plan => PRDs => task-master on prds. Used the following to create /architect_game_systems)
Read the .firecrawl/snake-gameplay-extracted.md as a game design document.

You are tasked with analyzing Game Design Documents (GDDs) and architecting the top-level major code systems necessary to implement the game. Before breaking down the GDD into systems, you will:
1. Identify any potential technical challenges not explicitly mentioned in the PRD without discarding any explicit requirements or going overboard with complexity. -- always aim to provide the most direct path to implementation, avoiding over-engineering or roundabout approaches
2. Make sure your content is relevant to Godot 4 game engine and not other Godot versions

Each system should represent a logical module that handles an aspect of the game. Each system should have a stated goal or purpose and ideally be a pure functional stateless code with inputs and outputs. Prefer modules modifying objects passed by reference instead of creating and updating a state themselves. Export your results into .taskmaster/docs/systems.md.

The goal is to describe a simple playable vertical slice of the game that will be implemented in godot.

(trying again but before we make the system design document we make the GDD)

/clarify_game_design .firecrawl/snake-gameplay-extracted.md

(then /architect_game_systems thoughts/shared/game-design/2026-05-27-ENG-snake.md)

(New run after not having worked on this project for a really long time. Was in iceland. Going to just redo the previous run.)

/clarify_game_design .firecrawl/snake-gameplay-extracted.md

(Then /architect_game_systems thoughts/shared/game-design/2026-06-20-ENG-snake.md)

/architect_game_systems thoughts/shared/game-design/2026-06-20-ENG-snake.md

(Then parsed)

task-master parse-prd -i .taskmaster/docs/systems.md

--BEGIN VAMPIRE SURVIVORS--

(I opted to start working on a vampire survivors clone because I felt like snake was a bit too simple. I copy and pasted the wikipedia gameplay summary. Now I just need to know what systems the LLM needs to know more details about to continue)

Is the @.firecrawl/vampire-survivors-gameplay-extracted.md ready to be transformed into a full fledged game? Are there any systems or features that need to be described in detail more? Don't ask me to clarify any systems. Simply identify and list the features and systems that need more information.

(Exported the missing details to todo-missing-details.md. There is a lot of missing gameplay and system requirements missing and that data lives in the vampire survivors wiki not the wikipedia. So I will manually scrape aka copy paste as a human to ensure I don't get IP banned.)

(Actually, didn't do anything special. Just hit CTRL+S to save out every page I thought was relevent as a Web Page, HTML only. Then used some random claude code scripts to convert them to .md and strip out stuff that was probably not needed. We should now be ready to make a /clarify_game_design call and reference the wiki as the source of truth)

