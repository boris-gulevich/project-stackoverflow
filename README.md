<h1><img src="http://imgur.com/1ZcRyrc.png" alt="GA logo" width="42px" height="42px" align="left" style="margin:-9px 10px">Predicting Stack Overflow Tags with PySpark and AWS</h1>

In this project, select tags for programming questions are predicted from question text. The notebook not only may serve as an example of how particular data science problems may be solved or how different tools may be used for a given purpose, yet also aims to give an approach to creating a set of simple models that could aid users decide on the optimal tags to assign to a question, by suggesting the likely candidates.

The data used to accomplish this goal are the raw dump of all Stack Overflow posts published by mid-March 2018. Given the size of the dataset and so the tools that are used, there are several smaller tasks involved, these are as follows.

- first, locally or using a single instance,
<br>&nbsp;&nbsp;&nbsp;1. preprocess the raw data that comes as an XML file and write the output to an AWS PostgreSQL database
<br>&nbsp;&nbsp;&nbsp;2. explore the data and decide on optimal partitioning and size of the cluster to use in modelling
- then, having created a cluster and installed the necessary software,
<br>&nbsp;&nbsp;&nbsp;3. process and explore the data further using PySpark to better engineer features and optimise the models
<br>&nbsp;&nbsp;&nbsp;4. train and test different algorithms and save the results and the best model for each tag

There is also an extra part that goes before modelling. It further explores and visualises the data treating the tags and connections between them as a network, to show how more can be learnt from this information by using it in a different way.

**The raw data** that comes as an XML file were downloaded from [archive.org/details/stackexchange](https://archive.org/details/stackexchange) and provided by the Stack Exchange Network. After the preprocessing, the size of the created PostgreSQL database is about 30 gigabytes.

**Core tools** used throughout the notebook are given below.
- lxml, re, NLTK, TextBlob, SpaCy and SQLAlchemy
- NumPy, pandas, Matplotlib, Seaborn and NetworkX
- PySpark and AWS (RDS, S3 and EMR)

**The notebook**, [`notebook_stackoverflow.ipynb`](http://nbviewer.jupyter.org/github/boris-gulevich/project-stackoverflow/blob/master/notebook_stackoverflow.ipynb), contains the Python code and all the plots and Bash and AWS CLI commands. **The bootstrap script** for the EMR cluster is given in a separate file, [`bootstrap_actions.sh`](./bootstrap_actions.sh).
