ind<-read.csv("ownCloud/abm/results/May24/covid19_ind.csv")
covid<-read.csv("ownCloud/abm/results/May24/covid19.csv")

ind<-read.csv("ownCloud/abm/covid/covid19_ind.csv")
covid<-read.csv("ownCloud/abm/covid/covid19.csv")
ind2$run<-ind2$run + 10000
covid2$run <- covid2$run + 10000

ind<-rbind(ind,ind2)
covid<-rbind(covid,covid2)

x<-NULL
baseline<-ind[ind$pctApp==0 & ind$pctTest==0 & ind$lockdown == "false" & ind$schools == "false",]
ideal<-ind[ind$pctApp==100 & ind$pctTest==25 & ind$compliance == "Low" & ind$schools == "false",]
plausible<-ind[ind$pctApp==40 & ind$pctTest==1.5 & ind$compliance == "Low" & ind$schools == "false",]
optimistic<-ind[ind$pctApp==60 & ind$pctTest==3 & ind$compliance == "Low" & ind$schools == "false",]
#x80<-ind[ind$pctApp==80 & ind$pctTest==1.5 & ind$compliance == "High" & ind$schools == "false",]

testingonl<-ind[ind$pctApp==0 & ind$pctTest==25 & ind$compliance == "false" & ind$schools == "false",]
apponl<-ind[ind$pctApp==100 & ind$pctTest==0 & ind$compliance == "High" & ind$schools == "false",]
fewtests<-ind[ind$pctApp==0 & ind$pctTest==0.4 & ind$compliance == "High" & ind$schools == "false",]


allT<-covid[covid$schools=="false" & covid$pctTest>=25 & covid$compliance=="High",]

a<-NULL
i<-1
for(a in unique(allT$pctApp)){
  this<-covid[covid$run %in% unique(allT[allT$pctApp==a,]$run),]
  this$diff<-apply(this[c("propInfected")], 1, function (x) abs(x - median(this$propInfected)))
  this<-this[order(this$diff),]
  #meds<-rbind(meds,this[1,]) 
  x[i]<-this[1,]$run
  i<-i+1
}


x<-NULL

plausibleruns<-covid[covid$run %in% unique(plausible$run),]
plausibleruns$diff<-apply(plausibleruns[c("propInfected")], 1, function (x) abs(x - median(plausibleruns$propInfected)))
plausibleruns<-plausibleruns[order(plausibleruns$diff),]
x[1]<-plausibleruns[1,]$run
#plot(ind[ind$run==x,]$infected)

baseruns<-covid[covid$run %in% unique(baseline$run),]
baseruns$diff<-apply(baseruns[c("propInfected")], 1, function (x) abs(x - median(baseruns$propInfected)))
baseruns<-baseruns[order(baseruns$diff),]

x[2]<-baseruns[1,]$run
#plot(ind[ind$run==x,]$infected)

idealruns<-covid[covid$run %in% unique(ideal$run),]
idealruns$diff<-apply(idealruns[c("propInfected")], 1, function (x) abs(x - median(idealruns$propInfected)))
idealruns<-idealruns[order(idealruns$diff),]
x[3]<-idealruns[1,]$run

optimisticruns<-covid[covid$run %in% unique(optimistic$run),]
optimisticruns$diff<-apply(optimisticruns[c("propInfected")], 1, function (x) abs(x - median(optimisticruns$propInfected)))
optimisticruns<-optimisticruns[order(optimisticruns$diff),]
x[4]<-optimisticruns[1,]$run

#x80runs<-allT[allT$run %in% unique(x80$run),]
#x80runs$diff<-apply(x80runs[c("propInfected")], 1, function (x) abs(x - median(x80runs$propInfected)))
#x80runs<-x80runs[order(x80runs$diff),]
#x[5]<-x80runs[1,]$run

covid_plot<-ind[ind$run %in% x,]
covid_plot$run<-as.factor(covid_plot$run)
ggplot(covid_plot, aes(x=t,y=(infected / 11934) * 100, color=run)) +
  geom_line(size=1.5) +
  scale_color_brewer(type = "qual",palette = "Set1",#values = c("#FE642E","#04B404","#08088A","#000000"), 
  labels = c("tests = 0; \napp = 0",
                                                                          "tests = 0.5% p.w. \napp = 40% \ncompliance: low",
                                                                          "tests = 1.5% p.w. \napp = 60% \ncompliance: high",
                                                                           "tests = ∞ \napp = 100% \ncompliance: high")) +
  #labels = c("app = 0;","app = 40%","app = 60%", "app = 100%")) +
  #ylim(0,11) +
  theme_minimal()+
  labs(x="Day",y="% Infected",color="Run")+
  theme(legend.text = element_text(size = 14),legend.position = "bottom",legend.title = element_blank(),
        axis.title = element_text(size = 14),axis.text = element_text(size = 14),legend.key.height=unit(2, "cm"))

ggsave(filename = "UnlimitedTestsIsolation.png")



png("isolating.png")     
plot(baseline$infected, type="l", col="black", xlab = "day", ylab = "# infected")
lines(ideal$infected, col="red")
lines(plausible$infected, col="grey")
lines(testingonl$infected, col="green")
lines(apponl$infected, col="blue")

plotcols<-c("black","red","blue","green","grey")

legend("topright", c("tests=0 app=0","tests=∞ app=100%","tests=0 app=100%","tests=∞ app=0",
                     "app=40% tests=1%"), col=plotcols, lty=1);
title(main = "progression of epidemic")
dev.off()

##############################################################################################

covid10<-read.csv("ownCloud/covid/abm/covid19_i10.csv")
covid4<-read.csv("ownCloud/covid/abm/covid19_i4.5.csv")

covid<-read.csv("ownCloud/abm/covid/covid19.csv")
covid[covid$schools=="true",]$schools<-TRUE
covid[covid$schools=="false",]$schools<-FALSE


covid4<-covid4[covid4$schools == F,]
covid10<-covid10[covid10$deaths>0 & covid10$mortality <= 5,]




plot(allT[allT$schools==FALSE,]$pctApp,((allT[allT$schools==FALSE,]$tests/11934/54))*100,xlab = "% App",ylab = "tests performed per week (% of population)", main ="Unlimited tests condition (schools closed)")


covid<-covid[covid$schools==FALSE,]

noSC<-covid[covid$schools=="false",]

noLD$manyapp<-noLD$pctApp>70

LD<-covid[covid$lockdown==TRUE,]

someapp<-covid[covid$pctApp>0,]

baseline<-covid[covid$schools=="false" & covid$pctApp==0 & covid$pctTest==0,]
plausible <- covid[covid$schools=="false" & covid$pctApp==40 & covid$pctTest==0.5 & covid$compliance=="Low",]
optimistic <- covid[covid$schools=="false" & covid$pctApp==60 & covid$pctTest==1.5 & covid$compliance=="High",]
ideal <- covid[covid$schools=="false" & covid$pctApp==100 & covid$pctTest==25 & covid$compliance=="High",]

noApp<-allT[allT$pctApp==0,]
x40app<-allT[allT$pctApp==40,]
x60App<-allT[allT$pctApp==60,]
allApp<-allT[allT$pctApp==100,]


noTest<-covid[covid$schools=="false" & covid$pctTest==0 & covid$compliance == "High",]
noApp<-covid[covid$schools=="false" & covid$pctApp==0,]


noApp<-covid[covid$schools=="false" & covid$pctApp==0,]

optim<-covid[covid$schools=="false" & covid$pctTest==1.5 & covid$compliance=="High",]
plau<-covid[covid$schools=="false" & covid$pctTest==0.5 & covid$compliance=="High",]

noSchools<-covid[covid$schools=="false",]

attach(noSchools)

p<-lm(propInfected ~ pctApp + pctTest + schools + compliance)
m<-lm(deaths ~ pctApp + pctTest + schools  + compliance)

summary(m)

boxplot(covid$propInfected ~ covid$pctApp*covid$pctTest, names(paste(covid$pctApp, covid$pctTest)), las=3)

summary(lm(covid$deaths ~ covid$lockdown))

summary(lm(noLD$deaths ~ noLD$pctApp + noLD$pctTest))


covid<-noSchools
summary(lm(fewTests$deaths ~ fewTests$pctApp))
allTest<-maxTest
summary(lm(noTest$propInfected ~ noTest$pctApp))
summary(lm(noApp$propInfected ~ noApp$pctTest))

boxplot(noTest$deaths ~ noTest$pctApp, xlab="% with app", ylab = "# deaths", main="no tests")
boxplot(noTest$propInfected ~ noTest$pctApp,  xlab="% with app", ylab = "prop. infected", 
        main="no tests")

png("noAppDeaths.png")
boxplot(noApp$deaths ~ noApp$pctTest, xlab="tests per 100 residents", ylab = "# deaths", main="no app")
dev.off()
png("noAppByTests.png")
boxplot(noApp$propInfected ~ noApp$pctTest, ylim=c(40,60), xlab="tests per 100 residents per week", ylab = "% infected", main="no app, schools closed")
dev.off()
png("noAppR0.png")
boxplot(noApp$R0 ~ noApp$pctTest, xlab="tests per 100 residents", ylab = "R0", main="no app")
dev.off()

png("optimByApp.png")
boxplot(optim$propInfected ~ optim$pctApp, ylim=c(20,60), xlab="App adoption", ylab = "prop. infected", main="1.5% population tested p.w.")
dev.off()

png("plauByApp.png")
boxplot(plau$propInfected ~ plau$pctApp, ylim=c(20,60), xlab="App adoption", ylab = "prop. infected", main="0.5% population tested p.w.")
dev.off()

png("allTestsDeaths.png")
boxplot(allT$deaths ~ allT$pctApp, xlab="App adoption", ylab = "# deaths", main="100% tests")
dev.off()
png("allTestsByApp.png")
boxplot(allT$propInfected ~ allT$pctApp, ylim=c(20,60), xlab="App adoption", ylab = "prop. infected", main="Unlimited tests")
dev.off()
png("allTestsR0.png")
boxplot(allTest$R0 ~ allTest$pctApp, xlab="App adoption", ylab = "R0", main="Unlimited tests")
dev.off()

png("noTestsDeaths.png")
boxplot(noTest$deaths ~ noTest$pctApp, xlab="App adoption", ylab = "# deaths", main="no tests, schools closed")
dev.off()
png("noTestsByApp.png")
boxplot(noTest$propInfected ~ noTest$pctApp, ylim=c(40,60), xlab="App adoption", ylab = "% infected", main="no tests, schools closed")
dev.off()
png("noTestsR0.png")
boxplot(noTest$R0 ~ noTest$pctApp, xlab="App adoption", ylab = "R0", main="no tests")
dev.off()

library(ggplot2)
ggplot(baseline, aes(x=schools,y=propInfected))+
  geom_boxplot(width=0.20) +
  ylim(45,70)
  labs(title = "No app, no tests", x="Schools open?", y="% infected")
ggsave("schoolClosure.png")

library(ggplot2)
ggplot(optimistic, aes(x=schools,y=propInfected))+
  geom_boxplot(width=0.20) +
  ylim(45,70)
labs(title = "No app, no tests", x="Schools open?", y="% infected")
ggsave("schoolClosureOptimistic.png")

png("schoolClosure.png")
boxplot(baseline$propInfected ~ baseline$schools, ylim=c(45,70), xlab="Schools open?", ylab = "% infected", main="No app, no tests")
dev.off()

png("schoolClosurePlausible.png")
boxplot(plausible$propInfected ~ plausible$schools,  ylim=c(45,70), xlab="Schools open?", ylab = "% infected", main="40% app, 0.5% tests p.w., low compliance")
dev.off()

png("schoolClosureoptimistic.png")
boxplot(optimistic$propInfected ~ optimistic$schools,  ylim=c(45,70), xlab="Schools open?", ylab = "% infected", main="60% app, 1.5% tests p.w., high compliance")
dev.off()

png("realDeaths.png")
boxplot(real$deaths ~ real$pctApp, xlab="% with app", ylab = "# deaths", main="1.6% tests")
dev.off()
png("realInfect_p10.png")
boxplot(real$propInfected ~ real$pctApp,xlab="% with app", ylab = "prop. infected", main="1.6% tests (p = 10)")
dev.off()

boxplot(covid$propInfected ~ covid$schools)
boxplot(covid$deaths ~ covid$schools)


plot(covid$propInfected,covid$deaths)
cor(covid$propInfected,covid$deaths)


pct<-unique(covid$pctApp)
tests<-unique(covid$pctTest)
lock<-unique(covid$lockdown)
sch<-unique(covid$schools)

covidM<-covid[FALSE,-1]

for(a in pct){
  for(t in tests){
    for(s in sch){
      
      fava<-covid[covid$pctApp==a & covid$pctTest==t & covid$schools==s,]
      hd<-fava[1,2:5]
      tail<-as.data.frame(t(colMeans(fava[6:ncol(fava)])))
      
      #this<-rbind(covidM,cbind(hd,tail))
      covidM<-rbind(covidM,cbind(hd,tail))
      
      #outp<-rbind(outp,cbind(hd,tail))
    }  
  }
}