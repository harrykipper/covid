#################################| DIAGRAMS OF SELECT PARAMETERS =========================

## Beta

covid<-read.csv("results/lotsofrandom.csv")
sensi<-read.csv("results/sensitivity/sensitivity-b.csv")
sensi$run<-sensi$run+10000
covid<-rbind(covid,sensi)


freq<-covid[covid$pctTest==100 & covid$compliance=="High" & covid$SymPriority=="true",]
freq$base<-as.factor(ifelse(freq$beta==0.08,1,0))
freq$beta<-as.factor(freq$beta)

ggplot(freq,aes(x=pctApp, y=propInfected, group=beta, lty=base)) +
  labs(y="% infected",x="% app adoption", title = expression(paste("t = unlim.; f = 0; ", lambda," = 0.01; p_rnd_inf = 0.1"))) +
  theme_bw() +
  ylim(0,70) +
  theme(axis.text = element_text(size = 15), axis.title = element_text(size=16), 
  legend.text = element_text(size=15), axis.title.y = element_text(margin = margin(t = 0, r = 15, b = 0, l = 0))) + 
  stat_summary(fun.y = median, geom = 'line', show.legend=FALSE) +
  annotate("text", x = 10, y = 1, label = expression(paste(beta, " = 0.04"))) +
  annotate("text", x = 10, y = 4, label = expression(paste(beta, " = 0.06"))) +
  annotate("text", x = 10, y = 33, label = expression(paste(beta, " = 0.08"))) +
  annotate("text", x = 10, y = 50, label = expression(paste(beta, " = 0.1"))) +
  annotate("text", x = 10, y = 62, label = expression(paste(beta, " = 0.12"))) 
  ggsave(filename = paste0(dir,"/sensitivity-t100-beta.png"), width = 6, height = 6)


# Lambda
  
  covid<-read.csv("results/lotsofrandom.csv")
  sensi<-read.csv("results/sensitivity/sensitivity-l.csv")
  sensi$run<-sensi$run+10000
  covid<-rbind(covid,sensi)
  
elle<-covid[covid$pctTest==100 & covid$compliance=="High" & covid$SymPriority=="true",]
elle$base<-as.factor(ifelse(elle$lambda==0.01,1,0))
elle$lambda<-as.factor(elle$lambda)

ggplot(elle,aes(x=pctApp, y=propInfected, group=lambda, lty=base)) +
  labs(y="% infected",x="% app adoption",  title = expression(paste("t = unlim.; f = 0; ", beta, " = 0.08; p_rnd_inf = 0.1"))) +
  theme_bw() +
  ylim(8,60) +
  theme(
    axis.text = element_text(size = 15), axis.title = element_text(size=16), 
    legend.text = element_text(size=16), axis.title.y = element_text(margin = margin(t = 0, r = 15, b = 0, l = 0))) + 
  stat_summary(fun.y = median, geom = 'line', show.legend=FALSE) +
  annotate("text", x = 4, y = 34, label = expression(paste(lambda, " = 0.0125"))) +
  annotate("text", x = 4, y = 22, label = expression(paste(lambda, " = 0.0075"))) +
  annotate("text", x = 4, y = 15, label = expression(paste(lambda, " = 0.0025"))) +
  annotate("text", x = 4, y = 28, label = expression(paste(lambda, " = 0.01"))) +
  annotate("text", x = 4, y = 44, label = expression(paste(lambda, " = 0.015"))) +
  annotate("text", x = 4, y = 53, label = expression(paste(lambda, " = 0.02")))
  ggsave(filename = paste0(dir,"/sensitivity-t100-lambda.png"), width = 6, height = 6)



  
# P
  
  
covid<-read.csv("results/lotsofrandom.csv")
sensi<-read.csv("results/sensitivity/sensitivity-p.csv")
sensi$run<-sensi$run+10000
covid<-rbind(covid,sensi)
  
#inf<-covid[covid$pctTest==1.5 & covid$lambda==0.01 & covid$fq.friends==2,]
inf<-covid[covid$pctTest==100 & covid$compliance=="High" & covid$SymPriority=="true",]

inf$base<-as.factor(ifelse(inf$prob.rnd.infection==0.1,1,0))
inf$prob.rnd.infection<-as.factor(inf$prob.rnd.infection)

ggplot(inf,aes(x=pctApp, y=propInfected, group=prob.rnd.infection, lty=base)) +
  labs(y="% infected",x="% app adoption", title = expression(paste("t = unlim.; f = 0; ", beta, " = 0.08; ", lambda," = 0.01"))) +
  theme_bw() +
  ylim(8,60) +
  theme(axis.text = element_text(size = 15), axis.title = element_text(size=16), 
        legend.text = element_text(size=16), axis.title.y = element_text(margin = margin(t = 0, r = 15, b = 0, l = 0))) + 
  stat_summary(fun.y = median, geom = 'line', show.legend=FALSE) +

  annotate("text", x = 10, y = 54, label = "p_rnd_inf = 0.2") +
  annotate("text", x = 10, y = 44, label = "p_rnd_inf = 0.15") +
  annotate("text", x = 10, y = 39, label = "p_rnd_inf = 0.125") +
  annotate("text", x = 10, y = 32, label = "p_rnd_inf = 0.1") +
  annotate("text", x = 10, y = 26, label = "p_rnd_inf = 0.075") +
  annotate("text", x = 10, y = 19, label = "p_rnd_inf = 0.05") +
  annotate("text", x = 10, y = 12, label = "p_rnd_inf = 0.0075") +
  annotate("text", x = 10, y = 8, label = "p_rnd_inf = 0.005") +
ggsave(filename = paste0(dir,"/sensitivity-t100-prob_rnd_inf.png"), width = 6, height = 6)



# F

covid<-read.csv("results/lotsofrandom.csv")
sensi<-read.csv("results/sensitivity/sensitivity-b.csv")
sensi$run<-sensi$run+10000
covid<-rbind(covid,sensi)

#inf<-covid[covid$pctTest==1.5 & covid$lambda==0.01 & covid$fq.friends==2,]
inf<-covid[covid$pctTest==1.5 & covid$compliance=="High" & covid$SymPriority=="true",]

inf$base<-as.factor(ifelse(inf$f==0,1,0))
inf$prob.rnd.infection<-as.factor(inf$f)

ggplot(inf,aes(x=pctApp, y=propInfected, group=prob.rnd.infection, lty=base)) +
  labs(y="% infected",x="% app adoption", title = expression(paste("t = 1.5%; p_rnd_inf = 0.1; ", beta, " = 0.08; ", lambda," = 0.01"))) +
  theme_bw() +
  ylim(10,35) +
  theme(axis.text = element_text(size = 15), axis.title = element_text(size=16), 
        legend.text = element_text(size=16), axis.title.y = element_text(margin = margin(t = 0, r = 15, b = 0, l = 0))) + 
  stat_summary(fun.y = median, geom = 'line', show.legend=FALSE) +
  
  annotate("text", x = 21, y = 35, label = "f = 0.75") +
  annotate("text", x = 21, y = 34, label = "f = 0.50") +
  annotate("text", x = 6, y = 30, label = "f = 0.25") +
  annotate("text", x = 6, y = 29, label = "f = 0") +
  annotate("text", x = 6, y = 24, label = "f = -0.25") +
  annotate("text", x = 6, y = 18, label = "f = -0.50") 
ggsave(filename = paste0(dir,"/sensitivity-t1.5-perDifFriends.png"), width = 6, height = 6)



#### Produce a diagram of all sensitivity combinations
sensitivity<-covid[covid$pctTest==100,]
dir<-"~/ownCloud/abm/sensitivity/"

for(f in unique(sensitivity$fq.friends)){
  for(l in unique(sensitivity$lambda)){
    for(p in unique(sensitivity$prob.rnd.infection)){
      
      fava<-sensitivity[sensitivity$fq.friends==f & sensitivity$lambda==l & sensitivity$prob.rnd.infection==p,]
      fava$pctApp<-as.factor(fava$pctApp)
      ggplot(fava,aes(x=pctApp, y=propInfected)) +
        geom_boxplot(show.legend=FALSE) +
        scale_fill_brewer(type = "seq",palette = "YlGnBu")+
        labs(y="% infected",x="% app adoption", title = paste0("t=100; fq=", f, "; ",expression(lambda),"=", l, "; p.rand=", p)) +
        
        theme_bw() +
        theme(axis.text = element_text(size = 15),
              axis.title = element_text(size=16),
              legend.text = element_text(size=16),
              axis.title.y = element_text(margin = margin(t = 0, r = 15, b = 0, l = 0))) + 
        stat_summary(fun.y = median, geom = 'line', group=1)
      ggsave(filename = paste0(dir,"/sensitivity_new-t100-fq",f,"-l",l,"-p",p,".png"), width = 6, height = 6)
    }
  }
}