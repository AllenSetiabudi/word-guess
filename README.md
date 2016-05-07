### Word Guess
######'Articulate'/'Charades'-like minigame plugin for L4D2 servers.

You know how you wait for people to join a pug, or join the server, and you wait and you wait and you wait, and then you think "I'm gonna bhop around while waiting", and then you realize it's eq/acemod so you can't bhop, so you die of boredom waiting five hours for people to join? Well this is *the* solution for your dying-of-boredom-while-waiting-for-a-pug-to-start problem.

Basically this is a word-guessing party game you can play while waiting for people to join. One person is the explainer who is given a word they have to explain (in mumble) without explicitly saying it, and everyone else has to guess what it is (by typing in chat). There are 60 seconds to explain as many words as you can before the role of explainer is passed to another player.

#### Useful commands:
- !playguess - Start/stop playing Word Guess
- !stopguess - Stop/start playing Word Guess
- !guesshelp - Give instructions on how to play
- !guesswho - Show a list of players and who has the role of explaining
- !word - As the explainer, reminds you what your current word is
- !newword - As the explainer, skip the current word and get a new one
- !pass - Pass if you do not want to be the explainer

#### Installation:
Yo you're a server owner so you can probably figure out what to do, but put **plugins/word_guess.smx** into your server's **addons/sourcemod/plugins/** folder and **gamedata/word_list.txt** into your server's **addons/sourcemod/gamedata/** folder.

There are currently 420 words in the supplied word list, but if they aren't (dank) enough, you can add your own; simply add your words to your **gamedata/word_list.txt** file. I'm happy to take suggestions to add to this supplied word list.

-Inspired by party games 'Articulate', 'Pictionary', 'Charades' and also by Ultra wanting to play 'I spy' during ready-up.
