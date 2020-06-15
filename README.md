# pl-quiz-importer
Convert a (simplified) text file into a CSV file for either Desire2Learn Brightspace or Blackboard Learn

This (small) program will convert a text file containing True/False and/or Multiple Choice questions into a format that can be imported into either Blackboard Learn or Desire2Learn Brightspace.  

You may create "categories" that the program can then show you how many questions per category were created.  Also has the ability to modify the "Points" and "Difficulty" if you are importing into Brightspace.

The script only is a single file.  You will need Perl on your system to use it.   It outputs the result to STDOUT (aka your screen), so just redirect it via > to a file of your choice.  (I often just output it to /dev/null while I am fix any errors with my input file, or you can just use -t which will only show the errors/warnings.)


## File format

The "idea" is to allow a super simple input file containing (just) the questions, and all answers.   It has the following format:

Multiple choice questions:

**question \<TAB\> wronganswer \<TAB\> *\*rightanswer* \<TAB\> wronganswer \<TAB\> ...**

True/False questions are even simpler:

**question \<TAB\> true-or-false**

More about the input file format:
* Continuation lines are just lines that begin with a \<TAB\>
* The correct answer will be the one that starts with a "\*" (MC questions only). 
* Answers can be entered in any order, and are sorted by default
* Sorting can be overridden (just start the question with a "!")
* You can use shortcuts for adding "all of the above" and "none of the above" (e.g. "+")
* Comments can be added (using the "#" character)
* Blank lines don't matter


## Usage:

   perl convert-q.pl [-b|-d|-t|-p] <input-file>
