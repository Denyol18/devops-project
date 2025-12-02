# Felhő és DevOps alapok gyak. projektmunka

Ez a repo a [programrendszerek fejlesztése projektmunka](https://github.com/Denyol18/prf-projekt) ci/cd implementációját tartalmazza, köztük:
- egy `Jenkinsfile` scriptet
- kettő `Dockerfile`-t, a szerver és kliens oldalak számára
- egy `app.tf` Terraform fájlt, amivel felépül, majd elindul az alkalmazás és a monitoringhoz szükséges rendszerek
- egy `prometheus.yml` fájlt, amivel a Prometheus kerül konfigurálásra
- és egy `pm2/ecosystem.config.js` fájlt, amivel a pm2 kerül konfigurálásra

## Pipeline beüzemelése nulláról:

1. Docker telepítése, verzió legalább 29.0.2 legyen
2. jenkins_home mappa létrehozása: `mkdir jenkins_home`
3. Jenkins dockerrel indítása: `docker run -d \
  --name jenkins \
  -p 8080:8080 -p 50000:50000 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v ~/jenkins_home:/var/jenkins_home \
  -v /usr/bin/docker:/usr/bin/docker \
  --group-add $(getent group docker | cut -d: -f3) \
  jenkins/jenkins:lts`
4. Jenkins beállítása: localhost:8080, kezdeti jelszó bemásolása ("docker logs jenkins"-ből), javasolt pluginek telepítése, felhasználó regisztrálása (nem muszáj), Save & Finish
5. Szükséges pluginok és toolok beállítása Jenkinsben: Nodejs és Terraform pluginek telepítése, Toolok között "nodejs" és "terraform" nevekkel automatikus installációk beállítása, NodeJS 24.11.1 és Terraform 1.13.4 linux (amd64) verzió megadása.
6. Pipeline létrehozása "prf-projekt-cicd" névvel, majd a pipeline beállításainál: Pipeline script from SCM -> SCM Gitre állítás -> repo url: https://github.com/Denyol18/devops-project -> Branch Specifier: */main
7. "Build Now" gombra kattintva pipeline indítása. Legelső build valamiért megbukik, de utána minden rendesen működik, a buildnek sikeresen végbe kell mennie.

## Projekt kipróbálása

Ahogy az a prf-projekt repo readme-jéből is olvasható, az applikáció egy egészségügyi adatkezelő, ami a MEAN (MongoDB, ExpressJS, Angular 2+, NodeJS) technológiai stack-ben valósult meg TypeScript alapon.

Felhasználó típusok: beteg és orvos.
A betegek feltölthetik mért értékeiket (pl.: vérnyomás, pulzus, súly, vércukor) a web-alkalmazásba bejelentkezés után. Az orvosok láthatják pácienseik alapadatait (név, születési dátum, születési hely, email, telefon) és az adott nap méréseit. A betegek regisztrálhatnak az alkalmazásban és választhatnak egy orvost, aki az adataikat ellenőrizni fogja. Az orvosok előre regisztrálva vannak.

Ez a projekt ki lett egészítve tesztekkel, logoló és metrikákat gyűjtő kódokkal.

A tesztek írásához a "jest", "jest-preset-angular" és "supertest", valamint a metrikák gyűjtéséhez a "prom-client" packagek lettek felhasználva.

A Prometheussal a default metrikák mellett a következő 5 custom metrika kerül begyűjtésre: httpRequestDuration, httpRequestTotal, dbConnectionErrors, dbQueryDuration, dbQueriesTotal

A Grayloggal HTTP Requestek kerülnek logolásra, ami a prf-projekt repoban a "winston" és "winston-graylog" packagek segítségével került megvalósításra.

Sikeres build után a következő portokon a következők érhetők el:
- 4200: Az app kliens oldala
- 3000: Az app szerver oldala
- 9090: Prometheus
- 4000: Grafana
- 9000: Graylog

### Grafana beüzemelése:

1. admin-admin párossal való bejelentkezés után a következők végrehajtása: data sources, add data source, prometheus, url: http://prometheus:9090, save & test
2. Dashboard készítéshez pedig: dashboards, create dashboard, add visualization, prometheus data source választása

### Graylog beüzemelése:

1. admin felhasználó névvel és a "docker logs graylog"-ból származó kezdeti jelszóval login
2. "Create CA", "Create Policy", "Provision certificate and continue" és a "Resume startup" (ha előjön) gombokon végigkattintás (lehet probléma a datanode-al, ezt a datanode konténer leállítása és újraindítása legtöbbször megoldja).
3. Újból login, ezúttal az admin-admin párossal
4. Input beállítása: system->inputs, select input->gelf udp, launch new input, inputnak névadás, launch input, set-up input, next, start input
5. A Search-re navigálás és az app használata után megjelennek a Graylog UI-on a logok.
