# MMS: Maxent Model Surveyor

Maxent Model Surveyor is a Perl program that evaluates different sets of predictors for Maxent niche modeling. It automatically calculates the Akaike and Bayesian information criteria (AIC, BIC; Warren & Seifert 2011) and the test AUC under the various predictor sets and suggests "suitable" predictor sets for your dataset.

MMS performs many Maxent runs sequentially. It then calculates test AUC, AIC and BIC for those different runs using code borrowed from ENMTools.

I've only used the program on my Linux server and on Mac OS X. Other users have reported that it runs on Windows 64 bit.

I've started to develop a brand new Java version of the program that is faster and has a graphical user interface and more features, so stay tuned. If you want to get notified when new versions are released, you could consider registering to receive my blog posts.

### User guide
MMS is a command-prompt program to be run in a terminal window. To open a terminal window, start the Terminal program (Mac OS X) or the Command Prompt (Windows). You will also have to install Perl for your platform if you don't already have it.

Once installed, put your species occurrence records and environmental rasters or SWD file in a folder. Copy the perl program to the same folder and navigate to this folder in the terminal window using the cd command (click for more info). Then type `perl MMS.pl`. This will show the parameter values that need to be given to the program (see also list below).

At minimum, you need to specify four parameters using command-line flags (environmental data, samples file, link to maxent jar file, and output file). Here's an example of how to do this if your occurrences are in occurrences.txt, your environmental rasters in a folder called `env_rasters`, and maxent.jar in the folder `/home/me/maxent`: 

```perl MMS.pl -e env_rasters -s occurrences.txt -m /home/me/maxent/maxent.jar -o output.txt```

You can then add optional parameters to tune what the program will do for you. You should probably not use the test AUC unless you have >30 occurrence records. Well, you probably shouldn't try making models at all if you have fewer than that.

Formatting your CSV file: A few things need to be kept in mind when preparing the CSV file with species occurrence records. First, make sure the first line of your CSV file has the column headers. These should include "species", "latitude" and "longitude" (without the quotation marks). Second, MMS works on a single species. If you have multiple species in your CSV, it will complain about this and tell you to make a separate CSV file for each species. Third, if you're working on Mac and have exported the CSV file from MS Excel, I've noticed that Maxent has trouble with the Mac line endings and no usable output is produced. In that case you should open the CSV file in a text editor and change the line endings to Unix (Edit > Document Options).

You have the option to customize Maxent's behavior by preparing a text file and providing it to MMS with the -ma flag. This file should have one setting per line, in the long form (flag column) documented in the Maxent documentation. For example, to prohibit Maxent from using product features, you could have a line product=false. Abbreviated flags or the "no" or "dont" forms should not be used. In fact, anything that is not of flag=value format is ignored. An example of a correctly formatted file can be downloaded here. Changing the java memory in the arguments file also won't work. This can be done directly on the command line with MMS's -jm flag (e.g. -jm 16000 for 16 gigabytes).

Here is a complete list of command-line flags you can use in this version.

```
mandatory parameters
   -e   environmental data
         name of directory containing rasters (raster mode)
         file with background csv data (SWD mode)
   -s   samples file
         sample coordinates in csv file (raster mode)
         sample data in csv format (SWD mode)
   -m   link to maxent jar file
   -o   output file

optional parameters
   -t   test samples file
         sample coordinates in csv file (raster mode)
         sample data in csv format (SWD mode)
         (using this option activates custom training/test mode)
   -me  method for variable selection (default: bss)
         bss : best subset selection
         bws : backward stepwise selection
         fws : forward stepwise selection
   -rc  evaluation criterion (default: AUC)
         AIC : Akaike Information Criterion
         AICc : corrected Akaike Information Criterion
         AUC : area under ROC curve (for test set)
         BIC : Bayesian Information Criterion
   -tt  number of replicate training and test data sets (default: 1)
         (disregarded when in custom training/test mode)
   -ma  file with arguments to be passed to maxent (one per line)
   -jm  java memory (in megabytes)
```

### Citation
If you find this software useful, please cite it in your work. I recommend citing it as follows:
Verbruggen H. (2012) Maxent Model Surveyor version 1.07. http://www.phycoweb.net/software

I also recommend citing the first paper that used and described the technique implemented here:
Verbruggen H., Tyberghein L., Belton G.S., Mineur F., Jueterbock A., Hoarau G., Gurgel C.F.D. & De Clerck O. (2013) Improving transferability of introduced species' distribution models: new tools to forecast the spread of a highly invasive seaweed. PLoS One 8: e68337.

### Notes and disclaimer
MMS is in development and has not been tested extensively. It is quite plausible that incorrectly formatted input could lead to nonsensical output.