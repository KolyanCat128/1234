#!/bin/bash -e
set -e
BRANCH=support/5.4.x
RUNTIME_BRANCH=support/2.x.x

echo -e "\033[32mPhase 0: \033[33mChecking\033[m";

which java || ( echo -e "\033[31mCheck failed: java not found. Please install JDK 21: \033[32https://gravitlauncher.com/install\033[m" && exit 1 );
which javac || ( echo -e "\033[31mCheck failed: javac not found. Please install JDK 21: \033[32https://gravitlauncher.com/install\033[m" && exit 1 );
which git || ( echo -e "\033[31mCheck failed: git not found. Please install git\033[m" && exit 1 );
#which curl || ( echo -e "\033[31mCheck failed: curl not found. Please install curl\033[m" && exit 1 );

(javac -version | grep " 21") || ( echo -e "\033[31mCheck failed: javac version unknown. Supported Java 21+. Please install JDK 21: \033[32https://gravitlauncher.com/install\033[m" && exit 1 );

echo -e "\033[32mPhase 1: \033[33mClone main repository\033[m";
git clone -b $BRANCH  https://github.com/GravitLauncher/Launcher.git src;
cd src;
sed -i 's/git@github.com:/https:\/\/github.com\//' .gitmodules;
git submodule sync;
git submodule update --init --recursive;
echo -e "\033[32mPhase 2: \033[33mBuild\033[m";
./gradlew -Dorg.gradle.daemon=false assemble || ( echo -e "\033[31mBuild failed. Stopping\033[m" && exit 100 );
cd ..;
mkdir libraries;
mkdir launcher-libraries;
mkdir launcher-libraries-compile;
ln -s src/LaunchServer/build/libs/LaunchServer.jar .;
ln -s ../src/LaunchServer/build/libs/libraries ./libraries/default;
ln -s ../src/LaunchServer/build/libs/launcher-libraries ./launcher-libraries/default;
ln -s ../src/LaunchServer/build/libs/launcher-libraries-compile ./launcher-libraries-compile/default;
chmod -R +x libraries/default/launch4j;
echo -e "\033[32mPhase 3: \033[33mClone runtime repository\033[m";
git clone -b $RUNTIME_BRANCH https://github.com/GravitLauncher/LauncherRuntime.git srcRuntime;
cd srcRuntime;
./gradlew -Dorg.gradle.daemon=false assemble || ( echo -e "\033[31mBuild failed. Stopping\033[m" && exit 100 );
cd ..;
echo -e "\033[32mPhase 4: \033[33mLinks\033[m";
mkdir modules;
ln -s srcRuntime/runtime .;
mkdir launcher-modules;
ln -s ../$(echo srcRuntime/build/libs/JavaRuntime*.jar) launcher-modules/;
mkdir compat;
ln -s ../srcRuntime/compat compat/runtime;
ln -s ../src/ServerWrapper/build/libs/ServerWrapper.jar compat/;
cat <<EOF > update.sh
#!/bin/bash -e
set -e
cd src && git stash && git pull && git submodule sync && git submodule update --init --recursive && \$(git stash apply | true) && ./gradlew -Dorg.gradle.daemon=false clean assemble && cd ..
cd srcRuntime && git stash && git pull && \$(git stash apply | true) && ./gradlew -Dorg.gradle.daemon=false clean assemble && cd ..
EOF
chmod +x update.sh
cat <<EOF > install_launchserver_module.sh
#!/bin/bash -e
set -e
if [ \$# -eq 0 ]; then
    >&2 echo "Usage: install_launchserver_module.sh MODULE_NAME"
    exit 1
fi
MODULE_FILE="src/modules/\$1_module/build/libs/\$1_module.jar"
if test -f \$MODULE_FILE
then
    ln -s ../\$MODULE_FILE modules/\$1_module.jar
else
    echo \$MODULE_FILE not exist
fi
EOF
chmod +x install_launchserver_module.sh

cat <<EOF > install_launcher_module.sh
#!/bin/bash -e
set -e
if [ \$# -eq 0 ]; then
    >&2 echo "Usage: install_launcher_module.sh MODULE_NAME"
    exit 1
fi
MODULE_FILE="src/modules/\$1_lmodule/build/libs/\$1_lmodule.jar"
if test -f \$MODULE_FILE
then
    ln -s ../\$MODULE_FILE launcher-modules/\$1_lmodule.jar
else
    echo \$MODULE_FILE not exist
fi
EOF
chmod +x install_launcher_module.sh

cat <<EOF > start.sh
#!/bin/bash
java -Xmx512M -javaagent:LaunchServer.jar -jar LaunchServer.jar
EOF
chmod +x start.sh
