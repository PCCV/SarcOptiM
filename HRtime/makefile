
JC = javac
JFLAGS = -g -deprecation
LIBS = /home/ImageJ/jars

SOURCEFILES = $(wildcard *.java)
CLASSFILES = $(SOURCEFILES:.java=.class)

DEST = ..

.SUFFIXES: .java .class

%.class:
	$(JC) $(JFLAGS) -extdirs $(LIBS) $*.java

# begin ---- JAR support ----------
JARFILE= HRtime.jar

$(JARFILE): $(CLASSFILES) $(SOURCEFILES)
	jar cf $(JARFILE) <<manifest.tmp *.class licence.txt COPYING.txt


default: $(CLASSFILES)

all: $(JARFILE) $(CLASSFILES) install clean

install:
	mv $(JARFILE) $(DEST)

clean:
	$(RM) *.class