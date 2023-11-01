ARG IMAGE=store/intersystems/iris-community:2020.1.0.204.0
ARG IMAGE=intersystemsdc/iris-community:2020.1.0.209.0-zpm
ARG IMAGE=intersystemsdc/iris-community:2020.2.0.204.0-zpm
ARG IMAGE=intersystemsdc/iris-community
FROM $IMAGE as builder

USER root

## workaround for sick restforms2 !!!
WORKDIR /opt/csp/irisapp
RUN chown ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} /opt/csp/irisapp
##

WORKDIR /opt/irisapp
RUN chown ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} /opt/irisapp
COPY irissession.sh /
RUN chmod +x /irissession.sh 

USER ${ISC_PACKAGE_MGRUSER}

COPY  Installer.cls .
COPY  src src
SHELL ["/irissession.sh"]

RUN \
  do $SYSTEM.OBJ.Load("Installer.cls", "ck") \
  set sc = ##class(App.Installer).setup() \
  zn "IRISAPP" \
  zpm "install restforms2" \
  zpm "install restforms2-ui" \
  do $System.OBJ.LoadDir("/opt/irisapp/src","ck",,1) \
  do ##class(Form.Util.Init).populateTestForms() \
  zn "%SYS" \
  write "Modify forms application security...",! \
  set webName = "/forms" \
  set webProperties("AutheEnabled") = 32 \
  set webProperties("MatchRoles")=":%DB_%DEFAULT" \
  set sc = ##class(Security.Applications).Modify(webName, .webProperties) \
  # if sc<1 write $SYSTEM.OBJ.DisplayError(sc) \
  write "Add Role for CSPSystem User...",! \
  set sc=##class(Security.Users).AddRoles("CSPSystem","%DB_%DEFAULT") 

# bringing the standard shell back
SHELL ["/bin/bash", "-c"]

FROM $IMAGE as final

ADD --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} https://github.com/grongierisc/iris-docker-multi-stage-script/releases/latest/download/copy-data.py /irisdev/app/copy-data.py

RUN --mount=type=bind,source=/,target=/builder/root,from=builder \
    cp -f /builder/root/usr/irissys/iris.cpf /usr/irissys/iris.cpf && \
    python3 /irisdev/app/copy-data.py -c /usr/irissys/iris.cpf -d /builder/root/ 
