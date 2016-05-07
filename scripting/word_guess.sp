//todo list:
//FEATURE: some sort of scoring system. maybe.
//FEATURE: change start/stopGuess from toggles into seperate commands

//FIX: Something weird happens when someone leaves to end the game?

//CLEAN: rename the !pass command in case of conflicts with other plugins?
//CLEAN: confusion caused by name 'isGameGoing' (rename to isEnoughPlayers or something?)
//CLEAN: remove commented debug prints/functions
//CLEAN: get rid of this todo list and add introductory comments

//I realize there are probably a few race conditions, but this is a damn minigame plugin lol
//To debug, swap commenting of indicated lines in 'isGameGoing()' and 'OnClientSayCommand_Post'

#include <sourcemod>
#include <colors>

#define ROUND_TIME 60
#define COUNTDOWN_SECONDS 5
#define WORD_LIST_PATH "gamedata/word_list.txt"

//Global vars
new String:currentWord[128];
new wordNumber;
new numberOfWords;
new bool:isPlaying[MAXPLAYERS + 1];
new turnsHad[MAXPLAYERS + 1];
new iExplainer;
new secondsLeft;
new Handle:arrayWordList;
new Handle:gameTimer;

public Plugin:myinfo =
{
  name = "Word Guess",
  author = "",
  description = "An 'Articulate'-like minigame",
  version = "1.8.1",
  url = ""
};

public OnPluginStart()
{
  //Set everyone to not playing and number of turns had to zero
  for (new player = 0; player <= MAXPLAYERS; player++)
  {
    isPlaying[player] = false;
    turnsHad[player] = 0;
  }

  //Initialize
  numberOfWords = countWords();
  if (numberOfWords == 0)
  {
    return; //Don't initialize if there was an error with the word list
  }
  arrayWordList = CreateArray(128);
  iExplainer = 0;
  wordNumber = -1;
  CreateWordList();
  ShuffleWordList();

  //Hook commands
  RegConsoleCmd("sm_countwords", Cmd_CountWords, "Count the number of words in the word list for debugging");
  RegConsoleCmd("sm_newword", Cmd_NewWord, "Skip the current word and change it to a new random word");
  RegConsoleCmd("sm_word", Cmd_Word, "Show the current word if you are the explainer");
  RegConsoleCmd("sm_pass", Cmd_Pass, "Pass if you do not want to be the explainer");
  RegConsoleCmd("sm_playguess", Cmd_Playing, "Toggle if you are playing Word Guess");
  RegConsoleCmd("sm_stopguess", Cmd_Playing, "Toggle if you are playing Word Guess");
  RegConsoleCmd("sm_guesshelp", Cmd_Help, "Print game instructions");
  RegConsoleCmd("sm_guesswho", Cmd_Who, "Show who are playing and who is the explainer");
}


////////
//Events
////////

public OnClientAuthorized(client, const String:auth[])
{
  isPlaying[client] = false;
  turnsHad[client] = 0;
}

public OnClientDisconnect_Post(client)
{
  new bool:wasGameGoing = isGameGoing();
  isPlaying[client] = false;
  turnsHad[client] = 0;
  //Stop the game if there were enough players, but now longer aren't since someone left
  if (wasGameGoing && !isGameGoing())
  {
    stopGame();
  }
  else if (isGameGoing() && client == iExplainer)
  {
    explainerLeft();
  }
}

public OnMapEnd()
{
  if (isGameGoing())
  {
    stopGame();
  }
}

//Notice when a playing player gueses the word
public OnClientSayCommand_Post(client, const String:command[], const String:sArgs[])
{
  if (isPlaying[client] && client != iExplainer) //Switch commenting with the line below to allow explainer to guess for debugging
  //if (isPlaying[client])
  {
    new String:guessedWord[sizeof(currentWord)];
    Format(guessedWord, sizeof(guessedWord), sArgs[0]);
    if(isGuessCorrect(guessedWord)) //If they've said the current word to be guessed
    {
      decl String:winnerName[128];
      decl String:message[256];
      GetClientName(client, winnerName, sizeof(winnerName));
      Format(message, sizeof(message),"{lightgreen}%s {default}got the word. It was {lightgreen}%s", winnerName, currentWord);
      PrintToPlayingClients(message);
      NextRandomWord();
    }
  }
}

//////////
//Commands
//////////

//Command to toggle if you are playing
public Action:Cmd_Playing(client, args)
{
  new bool:wasGameGoing = isGameGoing();
  isPlaying[client] = !isPlaying[client]; //Toggle whether the client is playing
  //Start/stop the game if there are now enough/not enough players
  if (wasGameGoing!=isGameGoing())
  {
    if (isGameGoing())
    {
      startGame();
    }
    else
    {
      stopGame();
    }
  }
  decl String:message[256];
  if (isPlaying[client])
  {
    Format(message, sizeof(message),"You are now playing Word Guess. Type {green}!guesshelp {default}for instructions");
    CPrintToChat(client, message);
    if (wasGameGoing == isGameGoing()) //If the player didn't cause a start or stop of the game
    {
      if (wasGameGoing)
      {
        // Show who is the current explainer
        decl String:explainerName[128];
        GetClientName(iExplainer, explainerName, sizeof(explainerName));
        Format(message, sizeof(message),"{lightgreen}%s {default}is the current explainer", explainerName);
        CPrintToChat(client, message);
      }
      else
      {
        Format(message, sizeof(message),"Still need one more player");
        PrintToChat(client, message);
      }
    }
  }
  else
  {
    Format(message, sizeof(message),"You are no longer playing Word Guess");
    PrintToChat(client, message);
    if (isGameGoing() && client == iExplainer)
    {
      explainerLeft();
    }
  }
  return Plugin_Handled;
}

//Command to show help
public Action:Cmd_Help(client, args)
{
  if (args == 1)
  {
    new String:arg[32];
    GetCmdArg(1, arg, sizeof(arg));
    if (StrEqual(arg, "more", false))
    {
      CPrintToChat(client, "As the explainer, type {green}!word {default}to show the current word, {green}!newword {default}to receive a new random word, and {green}!pass {default}to pass the role of explainer to someone else.");
      CPrintToChat(client, "Type {green}!playguess {default}to toggle whether you are playing. Type {green}!guesswho {default}to show who is the explainer and who else is playing.");
    }
    else
    {
      CPrintToChat(client, "Type {green}!guesshelp {default}for instructions and {green}!guesshelp more {default}for some useful commands.");
    }
  }
  else
  {
    PrintToChat(client, "Instructions: Each round one player is chosen as the explainer. Other players must guess (by typing in chat) as many randomly chosen words as they can in %i seconds.", ROUND_TIME);
    CPrintToChat(client, "The explainer must give hints to the words (in voice chat), without saying the words. Type {green}!guesshelp more {default}for some useful commands.");
  }
  return Plugin_Handled;
}

//Command to show who is playing and who the explainer is
public Action:Cmd_Who(client, args)
{
  if (isGameGoing())
  {
    PrintToChat(client, "List of players (explainer shown in orange):");
    for (new player = 0; player <= MAXPLAYERS; player++)
    {
      if (isPlaying[player])
      {
        decl String:playerName[128];
        GetClientName(player, playerName, sizeof(playerName));
        if (player == iExplainer)
        {
          CPrintToChat(client, "{green}%s", playerName);
        }
        else
        {
          CPrintToChat(client, "{lightgreen}%s", playerName);
        }
      }
    }
  }
  else
  {
    PrintToChat(client, "Game is not currently running");
  }
  return Plugin_Handled;
}

//Command to pass role of explainer to another player
public Action:Cmd_Pass(client, args)
{
  if (isGameGoing())
  {
    if (client == iExplainer)
    {
      //Stop the current round of the game and start a new one, effectively passing the role of explainer to someone else
      KillTimer(gameTimer);
      decl String:message[256];
      decl String:explainerName[128];
      GetClientName(iExplainer, explainerName, sizeof(explainerName));
      Format(message, sizeof(message),"{lightgreen}%s {default}is passing as the explainer", explainerName);
      PrintToPlayingClients(message);
      startRound();
    }
    else
    {
      PrintToChat(client,"You are not the explainer");
    }
  }
  else
  {
    PrintToChat(client, "Game is not currently running");
  }
  return Plugin_Handled;
}

//Command to show the number of words in the word list
public Action:Cmd_CountWords(client, args)
{
  CPrintToChat(client, "Number of words: {lightgreen}%i", numberOfWords);
  return Plugin_Handled;
}

//Command to skip the current word and move on to the next in the shuffled list
public Action:Cmd_NewWord(client, args)
{
  if (isGameGoing())
  {
    if (client != iExplainer)
    {
      PrintToChat(client,"You are not the explainer");
    }
    else
    {
      decl String:message[256];
      Format(message, sizeof(message),"Word being skipped. It was: {lightgreen}%s", currentWord);
      PrintToPlayingClients(message);
      NextRandomWord();
    }
  }
  else
  {
    PrintToChat(client,"Game is not currently underway");
  }
  return Plugin_Handled;
}

//Command to show the current word
public Action:Cmd_Word(client, args)
{
  if (isGameGoing())
  {
    //CPrintToChat(client, "random word is: {lightgreen}%s", currentWord);
    if (client == iExplainer)
    {
      CPrintToChat(client, "Random word is: {lightgreen}%s", currentWord);
    }
    else
    {
      PrintToChat(client,"You are not the explainer");
    }
  }
  else
  {
    PrintToChat(client,"Game is not currently underway");
  }
  return Plugin_Handled;
}

/////////////////////
//Word list functions
/////////////////////

//Function to count the number of words in the word list file
countWords()
{
  decl String:path[PLATFORM_MAX_PATH],String:line[128];
  BuildPath(Path_SM,path,PLATFORM_MAX_PATH,WORD_LIST_PATH);
  new Handle:fileHandle=OpenFile(path,"r");
  new iWords = 0;
  //For OpenFile(path,type): "Return: A Handle to the file, INVALID_HANDLE on open error."
  //Deal with open error here
  if (fileHandle == INVALID_HANDLE) //Dealing with open error
  {
    LogError("Word Guess: Error - file 'gamedata/word_list.txt' could not open (does it exist?)");
    return 0;
  }
  //Count the number of words (lines) in the file
  while(!IsEndOfFile(fileHandle)&&ReadFileLine(fileHandle,line,sizeof(line)))
  {
    iWords++;
  }
  CloseHandle(fileHandle);
  if (iWords == 0) //Dealing with empty word lists
  {
    LogError("Word Guess: Warning - file 'gamedata/word_list.txt' is empty");
  }
  return iWords;
}

//Function to create the word list from the file
CreateWordList()
{
  //Read in the word list from the word list file
  decl String:path[PLATFORM_MAX_PATH],String:line[128];
  BuildPath(Path_SM,path,PLATFORM_MAX_PATH,WORD_LIST_PATH);
  new Handle:fileHandle=OpenFile(path,"r");
  while(!IsEndOfFile(fileHandle)&&ReadFileLine(fileHandle,line,sizeof(line)))
  {
    ReplaceString(line, sizeof(line), "\r", "", false); //Remove carriage return characters
    ReplaceString(line, sizeof(line), "\n", "", false); //Remove newline characters
    PushArrayString(arrayWordList, line);
  }
  CloseHandle(fileHandle);
}

/*
PrintWordList()
{
  PrintToChatAll("printing word list to chat")
  decl String:word[128];
  for (new i = 0; i < GetArraySize(arrayWordList); i++)
  {
    GetArrayString(arrayWordList, i, word, sizeof(word));
    PrintToChatAll(word);
  }
}
*/

//Function to shuffle the word list
ShuffleWordList()
{
  //Explained at http://bost.ocks.org/mike/shuffle/
  decl String:frontShuffledWord[128];
  decl String:randomUnshuffledWord[128];
  for (new iFrontShuffled = numberOfWords - 1; iFrontShuffled > 0; iFrontShuffled--)
  {
    new iRandomUnshuffled = GetRandomInt(0,iFrontShuffled); //Pick a random element from the front unshuffled ones
    //Swap the randomly chosen unshuffled element with the front of the back stored elements :S
    GetArrayString(arrayWordList, iFrontShuffled, frontShuffledWord, sizeof(frontShuffledWord));
    GetArrayString(arrayWordList, iRandomUnshuffled, randomUnshuffledWord, sizeof(randomUnshuffledWord));
    SetArrayString(arrayWordList, iFrontShuffled, randomUnshuffledWord);
    SetArrayString(arrayWordList, iRandomUnshuffled, frontShuffledWord);
  }
}

/////////////////
//Round functions
/////////////////

//Randomly choose a new explainer. Someone other than the current explainer
//No longer used
/*
newExplainerOld()
{
  new playingClients = 0;
  for (new client = 0; client <= MAXPLAYERS; client++) //Count the number of playing clients excluding the current explainer
  {
    if (isPlaying[client] && client != iExplainer)
    {
      playingClients++;
    }
  }
  if (playingClients == 0) //If there is only 1 player (as during debugging)...
  {
    playingClients = 1;
    new randomClientNumber = GetRandomInt(1,playingClients); //Choose a random number up to the amount that are playing
    for (new client = 0; client <= MAXPLAYERS; client++) //Go through each player until you find the randomly chosen one
    {
      if (isPlaying[client])
      {
        randomClientNumber--;
        if (randomClientNumber==0)
        {
          iExplainer = client; //Assign the player as the new explainer
          turnsHad[iExplainer]++; //Count the turn they are having
        }
      }
    }
  }
  else //Only necessary if there is only one player and they are playing (when debugging)
  {
    new randomClientNumber = GetRandomInt(1,playingClients); //Choose a random number up to the amount that are playing
    for (new client = 0; client <= MAXPLAYERS; client++) //Go through each player until you find the randomly chosen one
    {
    	if (isPlaying[client] && client != iExplainer)
      {
        randomClientNumber--;
        if (randomClientNumber==0)
        {
        	iExplainer = client; //Assign the player as the new explainer
          turnsHad[iExplainer]++; //Count the turn they are having
        }
      }
    }
  }
  decl String:message[256];
  decl String:explainerName[128];
  GetClientName(iExplainer, explainerName, sizeof(explainerName));
  Format(message, sizeof(message),"{lightgreen}%s {default}is the new explainer", explainerName);
  PrintToPlayingClients(message);
}
*/

//Choose a new explainer who has had the least turns
newExplainer()
{
  new minTurns = 999; //Find a better way to do this
  new iNewExplainer = iExplainer;
   //Go through each player and find who has had the least number of turns
  for (new client = 0; client <= MAXPLAYERS; client++)
  {
    if (isPlaying[client] && client != iExplainer) //If you don't want to choose the same one
    {
      if (turnsHad[client] < minTurns) //Change to less than or equal to?
      {
        minTurns = turnsHad[client];
        iNewExplainer = client;
      }
    }
  }

  iExplainer = iNewExplainer; //Assign the player as the new explainer
  turnsHad[iExplainer]++; //Count the turn they are having

  decl String:message[256];
  decl String:explainerName[128];
  GetClientName(iExplainer, explainerName, sizeof(explainerName));
  Format(message, sizeof(message),"{lightgreen}%s {default}is the new explainer", explainerName);
  PrintToPlayingClients(message);
}

//Function to move on to the next word in the shuffled list
NextRandomWord()
{
  wordNumber++
  if (wordNumber == numberOfWords) //Reset the word list if you've reached the end
  {
    wordNumber = 0;
    ShuffleWordList();
    //PrintWordList();
  }
  //Get the next word in the list and set it as the current word
  decl String:word[128];
  GetArrayString(arrayWordList, wordNumber, word, sizeof(word));
  currentWord = word;
  CPrintToChat(iExplainer, "New random word is: {lightgreen}%s", currentWord);
}

//Return whether or not the game is currently running
bool:isGameGoing()
{
  //If there are at least 2 players, the game is running
  new bool:isOnePlaying = false;
  new bool:isTwoPlaying = false;
  for(new i = 0; i <= MAXPLAYERS; i++)
  {
    if (isPlaying[i])
    {
      if (isOnePlaying)
      {
        isTwoPlaying = true;
        i = MAXPLAYERS;
      }
      else
      {
        isOnePlaying = true;
      }
    }
  }
  return isTwoPlaying; //Switch commenting with the line below to allow solo play for debugging
  //return isOnePlaying;
}

//Handles the actions depending at what time the timer is at
public Action:timeNextSecond(Handle:timer)
{
  decl String:message[256];
  if (secondsLeft == 0) //Indicate when the time is up and start a new round
  {
    Format(message, sizeof(message), "{lightgreen}Time's Up");
    PrintToPlayingClients(message);
    Format(message, sizeof(message),"The word was: {lightgreen}%s", currentWord);
    PrintToPlayingClients(message);
    startRound();
  }
  else
  {
    //Show how much time is left at specified intervals
    if (secondsLeft == ROUND_TIME ||
      secondsLeft == ROUND_TIME / 2 ||
      secondsLeft == ROUND_TIME / 4 ||
      secondsLeft <= COUNTDOWN_SECONDS)
    {
      Format(message, sizeof(message), "Number of seconds left: {lightgreen}%i", secondsLeft);
      PrintToPlayingClients(message);
    }
    secondsLeft--; //Decrement the timer
    gameTimer = CreateTimer(1.0, timeNextSecond); //Continue to tick away
  }
}

//What to do if the explainer left (and the game is still going)
explainerLeft()
{
  KillTimer(gameTimer);

  decl String:message[256];
  Format(message, sizeof(message), "{lightgreen}The explainer has stopped playing");
  PrintToPlayingClients(message);
  Format(message, sizeof(message),"The word was: {lightgreen}%s", currentWord);
  PrintToPlayingClients(message);

  startRound();
}

startRound()
{
  decl String:message[256];
  Format(message, sizeof(message),"New round has begun!");
  PrintToPlayingClients(message);
  newExplainer();
  NextRandomWord();
  secondsLeft = ROUND_TIME; //Reset the timer (to 60 by default)
  gameTimer = CreateTimer(1.0, timeNextSecond); //Start the timer
}

startGame()
{
  decl String:message[256];
  Format(message, sizeof(message),"Game is starting...");
  PrintToPlayingClients(message);
  startRound();
}

stopGame()
{
  KillTimer(gameTimer);
  decl String:message[256];
  Format(message, sizeof(message), "{lightgreen}Game Over!");
  PrintToPlayingClients(message);
  //Reset some of the global variables
  currentWord = "";
  iExplainer = 0;
}

////////////////
//Misc functions
////////////////

//Prints messages only to playing clients
PrintToPlayingClients(String:message[256])
{
  for (new client = 0; client <= MAXPLAYERS; client++)
  {
    if (isPlaying[client])
    {
      CPrintToChat(client, message);
    }
  }
}

//Check if a guess is correct, taking into account dash, underscore and whitespace characters
bool:isGuessCorrect(String:guess[128])
{
  new String:guessedWord[sizeof(currentWord)];
  Format(guessedWord, sizeof(guessedWord), guess);
  ReplaceString(guessedWord, sizeof(guessedWord), "-", "", false); //Remove dashes characters
  ReplaceString(guessedWord, sizeof(guessedWord), "_", "", false); //Remove underscore characters
  ReplaceString(guessedWord, sizeof(guessedWord), " ", "", false); //Remove whitespace characters

  new String:currentWordCleaned[sizeof(currentWord)];
  Format(currentWordCleaned, sizeof(currentWordCleaned), currentWord);
  ReplaceString(currentWordCleaned, sizeof(currentWordCleaned), "-", "", false); //Remove dashes characters
  ReplaceString(currentWordCleaned, sizeof(currentWordCleaned), "_", "", false); //Remove underscore characters
  ReplaceString(currentWordCleaned, sizeof(currentWordCleaned), " ", "", false); //Remove whitespace characters

  return (StrEqual(currentWordCleaned,guessedWord, false));
}
