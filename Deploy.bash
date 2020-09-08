#Maven release plugin has two problems. The message it creates for the git annotated tag can’t be changed (hence a bad release message on GitHub); and the prepare goal creates an unnecessary and improperly aligned <tag> element in the POM (related discussion at https://stackoverflow.com/questions/23718601/what-is-the-usage-of-maven-pom-xml-tag-element-inside-of-scm-when-you-are). 

#Required for maven-javadoc-plugin
JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64/

mvn -Dmaven.version.rules=https://raw.githubusercontent.com/oliviercailloux/Deploy-script/master/rules.xml org.codehaus.mojo:versions-maven-plugin:2.8.1:display-dependency-updates
if [[ "$?" -ne 0 ]] ; then
  echo "Could not verify dependencies."
  exit 1
fi

CURRENT_VERSION=$(xmllint --xpath "/*[local-name()='project']/*[local-name()='version']/text()" pom.xml)
if [[ ${CURRENT_VERSION} != *-SNAPSHOT ]]; then
  echo "Current version is not a SNAPSHOT."
  exit 1
fi
CURRENT_VERSION_SHORT=$(echo ${CURRENT_VERSION} | sed -En 's/([^-]*)-SNAPSHOT/\1/p')
echo "Current version: '${CURRENT_VERSION}'; in short: '${CURRENT_VERSION_SHORT}'."
IFS='.' read -ra CURRENT_VERSION_SHORT_ARRAY <<< "$CURRENT_VERSION_SHORT"
CURRENT_VERSION_SHORT_LENGTH=${#CURRENT_VERSION_SHORT_ARRAY[@]}
if [ "${CURRENT_VERSION_SHORT_LENGTH}" -ne 3 ]; then
  echo "Unexpected current version short length."
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "There are uncommitted changes."
  exit 1
fi

xmllint --shell pom.xml << END                                                                 
cd /*[local-name()='project']/*[local-name()='version']
set ${CURRENT_VERSION_SHORT}
save
END
git commit -m "To version ${CURRENT_VERSION_SHORT}." pom.xml

mvn -Prelease clean deploy
if [[ "$?" -ne 0 ]] ; then
  echo "Could not deploy."
  exit 1
fi
git tag -a "v${CURRENT_VERSION_SHORT}"

NEXT_VERSION_SHORT="${CURRENT_VERSION_SHORT_ARRAY[0]}.${CURRENT_VERSION_SHORT_ARRAY[1]}.$((${CURRENT_VERSION_SHORT_ARRAY[2]} + 1))"
NEXT_VERSION=${NEXT_VERSION_SHORT}-SNAPSHOT

xmllint --shell pom.xml << END                                                                 
cd /*[local-name()='project']/*[local-name()='version']
set ${NEXT_VERSION}
save
END
git commit -m "Start version ${NEXT_VERSION}." pom.xml

git push origin master "v${CURRENT_VERSION_SHORT}"

