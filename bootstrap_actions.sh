#!/usr/bin/env bash
set -x -e

JUPYTER_PASSWORD=${1:-"<my jupyter password>"}
NOTEBOOK_DIR=${2:-"s3://<my bucket>/"}

# home backup
if [ ! -d /mnt/home_backup ]; then
  sudo mkdir /mnt/home_backup
  sudo cp -a /home/* /mnt/home_backup
fi

# mount home to /mnt
if [ ! -d /mnt/home ]; then
  sudo mv /home/ /mnt/
  sudo ln -s /mnt/home /home
fi

# install miniconda
wget https://repo.continuum.io/miniconda/Miniconda3-4.2.12-Linux-x86_64.sh -O /home/hadoop/miniconda.sh \
  && /bin/bash ~/miniconda.sh -b -p $HOME/conda

echo '\nexport PATH=$HOME/conda/bin:$PATH' >> $HOME/.bashrc && source $HOME/.bashrc

conda config --set always_yes yes --set changeps1 no

conda install conda

conda config --add channels conda-forge
conda config --add channels defaults
conda config --add channels intel

conda install hdfs3 findspark ujson jsonschema toolz boto3 py4j numpy pandas

# for all instances download the PostgreSQL driver
wget -O /home/hadoop/postgresql-42.2.1.jar "https://jdbc.postgresql.org/download/postgresql-42.2.1.jar"

# cleanup
rm ~/miniconda.sh

echo bootstrap_conda.sh completed. PATH now: $PATH
export PYSPARK_PYTHON="/home/hadoop/conda/bin/python3.5"

# for the master node only
IS_MASTER=false
if grep isMaster /mnt/var/lib/info/instance.json | grep true;
then
  IS_MASTER=true

  # install dependencies for s3fs to access and store notebooks
  sudo yum install -y git
  sudo yum install -y libcurl libcurl-devel graphviz cyrus-sasl cyrus-sasl-devel readline readline-devel gnuplot
  sudo yum install -y automake fuse fuse-devel libxml2-devel

  # extract BUCKET and FOLDER to mount from NOTEBOOK_DIR
  NOTEBOOK_DIR="${NOTEBOOK_DIR%/}/"
  BUCKET=$(python -c "print('$NOTEBOOK_DIR'.split('//')[1].split('/')[0])")
  FOLDER=$(python -c "print('/'.join('$NOTEBOOK_DIR'.split('//')[1].split('/')[1:-1]))")

  echo "bucket '$BUCKET' folder '$FOLDER'"

  cd /mnt
  git clone https://github.com/s3fs-fuse/s3fs-fuse.git
  cd s3fs-fuse/
  ls -alrt
  ./autogen.sh
  ./configure
  make
  sudo make install
  sudo su -c 'echo user_allow_other >> /etc/fuse.conf'
  mkdir -p /mnt/s3fs-cache
  mkdir -p /mnt/$BUCKET
  /usr/local/bin/s3fs -o allow_other -o iam_role=auto -o umask=0 -o url=https://s3.amazonaws.com  -o no_check_certificate -o enable_noobj_cache -o use_cache=/mnt/s3fs-cache $BUCKET /mnt/$BUCKET

  # install and configure jupyter notebook and other packages
  echo "installing python libs in master"
  conda install jupyter

  # install psycopg2 and sqlalchemy
  conda install psycopg2 sqlalchemy

  # install visualization packages
  conda install matplotlib seaborn

  # jupyter configs
  mkdir -p ~/.jupyter
  touch ls ~/.jupyter/jupyter_notebook_config.py
  HASHED_PASSWORD=$(python -c "from notebook.auth import passwd; print(passwd('$JUPYTER_PASSWORD'))")
  echo "c.NotebookApp.password = u'$HASHED_PASSWORD'" >> ~/.jupyter/jupyter_notebook_config.py
  echo "c.NotebookApp.open_browser = False" >> ~/.jupyter/jupyter_notebook_config.py
  echo "c.NotebookApp.ip = '*'" >> ~/.jupyter/jupyter_notebook_config.py
  echo "c.NotebookApp.notebook_dir = '/mnt/$BUCKET/$FOLDER'" >> ~/.jupyter/jupyter_notebook_config.py
  echo "c.ContentsManager.checkpoints_kwargs = {'root_dir': '.checkpoints'}" >> ~/.jupyter/jupyter_notebook_config.py

  # setup jupyter deamon and launch it, requires using yarn in client mode
  cd ~
  echo "creating Jupyter daemon"

  sudo cat <<EOF > /home/hadoop/jupyter.conf
description "Jupyter"

start on runlevel [2345]
stop on runlevel [016]

respawn
respawn limit 0 10

chdir /mnt/$BUCKET/$FOLDER

script
  sudo su - hadoop > /var/log/jupyter.log 2>&1 <<BASH_SCRIPT
    export PYSPARK_DRIVER_PYTHON="/home/hadoop/conda/bin/jupyter"
    export PYSPARK_DRIVER_PYTHON_OPTS="notebook --log-level=INFO"
    export PYSPARK_PYTHON=/home/hadoop/conda/bin/python3.5
    export JAVA_HOME="/etc/alternatives/jre"
    pyspark --driver-cores 5 --driver-memory 13498M --executor-cores 2 --executor-memory 14093M --conf spark.default.parallelism=248 --conf spark.driver.maxResultSize=0 --conf spark.serializer=org.apache.spark.serializer.KryoSerializer --conf spark.kryo.registrationRequired=false --conf spark.kryo.classesToRegister="org.apache.spark.sql.execution.columnar.CachedBatch,[[B,org.apache.spark.sql.catalyst.expressions.GenericInternalRow,[Ljava.lang.Object;,org.apache.spark.unsafe.types.UTF8String,org.apache.spark.mllib.feature.IDF""$""DocumentFrequencyAggregator,breeze.linalg.DenseVector""$""mcJ""$""sp,org.apache.spark.mllib.stat.MultivariateOnlineSummarizer,scala.math.Ordering""$""""$""anon""$""9,scala.math.Ordering""$""""$""anonfun""$""by""$""1,org.apache.spark.ml.feature.CountVectorizer""$""""$""anonfun""$""6,scala.math.Ordering""$""Long""$"",org.apache.spark.sql.execution.stat.StatFunctions""$""CovarianceCounter,org.apache.spark.ml.classification.MultiClassSummarizer,org.apache.spark.ml.optim.aggregator.LogisticAggregator,org.apache.spark.broadcast.TorrentBroadcast,org.apache.spark.storage.BroadcastBlockId,scala.reflect.ClassTag""$""""$""anon""$""1,java.lang.Class,org.apache.spark.ml.optim.aggregator.HingeAggregator,org.apache.spark.mllib.regression.LabeledPoint,[Lorg.apache.spark.ml.tree.Split;,org.apache.spark.ml.tree.ContinuousSplit,org.apache.spark.ml.tree.impl.DTStatsAggregator,org.apache.spark.mllib.tree.impurity.GiniAggregator,org.apache.spark.ml.tree.impl.DecisionTreeMetadata,scala.collection.immutable.HashMap""$""EmptyHashMap""$"",org.apache.spark.mllib.tree.impurity.Gini""$"",scala.Enumeration""$""Val,org.apache.spark.mllib.tree.configuration.QuantileStrategy""$"",scala.collection.immutable.Set""$""EmptySet""$"",org.apache.spark.mllib.tree.model.ImpurityStats,org.apache.spark.mllib.tree.impurity.GiniCalculator,[Lorg.apache.spark.ml.feature.LabeledPoint;,org.apache.spark.mllib.tree.impurity.EntropyAggregator,org.apache.spark.mllib.tree.impurity.Entropy""$"",org.apache.spark.mllib.tree.impurity.EntropyCalculator,org.apache.spark.mllib.tree.impurity.VarianceAggregator,org.apache.spark.mllib.tree.impurity.Variance""$"",org.apache.spark.mllib.tree.impurity.VarianceCalculator,org.apache.spark.mllib.evaluation.binary.BinaryLabelCounter,[Lorg.apache.spark.mllib.evaluation.binary.BinaryLabelCounter;,scala.collection.mutable.WrappedArray""$""ofRef,org.apache.spark.internal.io.FileCommitProtocol""$""TaskCommitMessage,[Lorg.apache.spark.sql.catalyst.InternalRow;,org.apache.spark.sql.catalyst.expressions.UnsafeRow,org.apache.spark.sql.execution.datasources.FileFormatWriter""$""WriteTaskResult,org.apache.spark.sql.execution.datasources.ExecutedWriteSummary,org.apache.spark.sql.execution.datasources.BasicWriteTaskStats,org.apache.spark.ml.regression.DecisionTreeRegressionModel,org.apache.spark.ml.classification.DecisionTreeClassificationModel,org.apache.spark.ml.param.BooleanParam,org.apache.spark.ml.param.ParamValidators""$""""$""anonfun""$""alwaysTrue""$""1,org.apache.spark.ml.param.IntParam,org.apache.spark.ml.param.shared.HasCheckpointInterval""$""""$""anonfun""$""1,org.apache.spark.ml.param.Param,org.apache.spark.ml.tree.TreeClassifierParams""$""""$""anonfun""$""1,org.apache.spark.ml.tree.TreeRegressorParams""$""""$""anonfun""$""3,org.apache.spark.ml.param.ParamValidators""$""""$""anonfun""$""gtEq""$""1,org.apache.spark.ml.param.DoubleParam,org.apache.spark.ml.param.ParamMap,org.apache.spark.ml.param.LongParam,org.apache.spark.ml.tree.InternalNode,org.apache.spark.ml.tree.LeafNode,org.apache.spark.ml.param.DoubleArrayParam,org.apache.spark.ml.param.shared.HasThresholds""$""""$""anonfun""$""2" --conf spark.kryoserializer.buffer.max=1024m --conf spark.locality.wait=10s --conf spark.task.maxFailures=8 --conf spark.ui.killEnabled=false --jars /home/hadoop/postgresql-42.2.1.jar --driver-class-path /home/hadoop/postgresql-42.2.1.jar:/usr/lib/hadoop-lzo/lib/*:/usr/lib/hadoop/hadoop-aws.jar:/usr/share/aws/aws-java-sdk/*:/usr/share/aws/emr/emrfs/conf:/usr/share/aws/emr/emrfs/lib/*:/usr/share/aws/emr/emrfs/auxlib/*:/usr/share/aws/emr/security/conf:/usr/share/aws/emr/security/lib/*:/usr/share/aws/hmclient/lib/aws-glue-datacatalog-spark-client.jar:/usr/share/java/Hive-JSON-Serde/hive-openx-serde.jar:/usr/share/aws/sagemaker-spark-sdk/lib/sagemaker-spark-sdk.jar --conf spark.executor.extraLibraryPath=/home/hadoop/postgresql-42.2.1.jar:/usr/lib/hadoop-lzo/lib/*:/usr/lib/hadoop/hadoop-aws.jar:/usr/share/aws/aws-java-sdk/*:/usr/share/aws/emr/emrfs/conf:/usr/share/aws/emr/emrfs/lib/*:/usr/share/aws/emr/emrfs/auxlib/*:/usr/share/aws/emr/security/conf:/usr/share/aws/emr/security/lib/*:/usr/share/aws/hmclient/lib/aws-glue-datacatalog-spark-client.jar:/usr/share/java/Hive-JSON-Serde/hive-openx-serde.jar:/usr/share/aws/sagemaker-spark-sdk/lib/sagemaker-spark-sdk.jar
  BASH_SCRIPT

end script
EOF

  sudo mv /home/hadoop/jupyter.conf /etc/init/
  sudo chown root:root /etc/init/jupyter.conf

  sudo initctl reload-configuration

  echo "starting Jupyter daemon"
  sudo initctl start jupyter

fi
