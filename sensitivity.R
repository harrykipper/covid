baseline<-covid[covid$pctTest==3 & covid$fq.friends==2 & covid$lambda==0.0050 & covid$prob.rnd.infection==0.1,]

infect<-covid[covid$pctTest==3 & covid$fq.friends==2 & covid$lambda==0.0050 & covid$prob.rnd.infection==0.2,]



covid<-read.csv("covid/sensitivity.csv")
covid_b$run<-covid_b$run+10000

covid<-rbind(covid,covid_b)

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
################################# DIAGRAMS OF SELECT PARAMETERS =========================

freq<-covid[covid$pctTest==3 & covid$lambda==0.0050 & covid$prob.rnd.infection==0.1,]
freq$base<-as.factor(ifelse(freq$fq.friends==2,1,0))
freq$fq.friends<-as.factor(freq$fq.friends)

ggplot(freq,aes(x=pctApp, y=propInfected, group=fq.friends, lty=base)) +
  labs(y="% infected",x="% app adoption", title = expression(paste("t = 3%; ", lambda," = 0.005; p_rnd_inf = 0.1"))) +
  theme_bw() +
  ylim(0,40) +
  theme(axis.text = element_text(size = 15), axis.title = element_text(size=16), 
  legend.text = element_text(size=15), axis.title.y = element_text(margin = margin(t = 0, r = 15, b = 0, l = 0))) + 
  stat_summary(fun.y = median, geom = 'line', show.legend=FALSE) +
  annotate("text", x = 10, y = 13, label = "fq_friends = 4") +
  annotate("text", x = 10, y = 22, label = "fq_friends = 2") +
  annotate("text", x = 10, y = 33, label = "fq_friends = 0") 
  ggsave(filename = paste0(dir,"/sensitivity_new-t3-freq.png"), width = 6, height = 6)


elle<-covid[covid$pctTest==3 & covid$fq.friends==2 & covid$prob.rnd.infection==0.1,]
elle$base<-as.factor(ifelse(elle$lambda==0.005,1,0))
elle$lambda<-as.factor(elle$lambda)

ggplot(elle,aes(x=pctApp, y=propInfected, group=lambda, lty=base)) +
  labs(y="% infected",x="% app adoption",  title = "t = 3%; fq_friends = 2; p_rnd_inf = 0.1") +
  theme_bw() +
  ylim(0,40) +
  theme(axis.text = element_text(size = 15), axis.title = element_text(size=16), 
        legend.text = element_text(size=16), axis.title.y = element_text(margin = margin(t = 0, r = 15, b = 0, l = 0))) + 
  stat_summary(fun.y = median, geom = 'line', show.legend=FALSE) +
  annotate("text", x = 4, y = 37, label = expression(paste(lambda, " = 0.01"))) +
  annotate("text", x = 4, y = 22, label = expression(paste(lambda, " = 0.005"))) +
  annotate("text", x = 4, y = 12, label = expression(paste(lambda, " = 0.0025"))) 
  # + annotate("text", x = 70, y = 55, label = expression(paste(lambda, " = 0.025"))) +
  #annotate("text", x = 60, y = 74, label = expression(paste(lambda, " = 0.05"))) +
  #annotate("text", x = 75, y = 88, label = expression(paste(lambda, " = 0.1")))
  ggsave(filename = paste0(dir,"/sensitivity_new-t3-lambda_tenfold.png"), width = 6, height = 6)



inf<-covid[covid$pctTest==3 & covid$lambda==0.0050 & covid$fq.friends==2,]
inf$base<-as.factor(ifelse(inf$prob.rnd.infection==0.2,1,0))
inf$prob.rnd.infection<-as.factor(inf$prob.rnd.infection)

ggplot(inf,aes(x=pctApp, y=propInfected, group=prob.rnd.infection, lty=base)) +
  labs(y="% infected",x="% app adoption", title = expression(paste("t = 3%; fq_friends = 2; ", lambda," = 0.005"))) +
  theme_bw() +
  #ylim(0,80) +
  theme(axis.text = element_text(size = 15), axis.title = element_text(size=16), 
        legend.text = element_text(size=16), axis.title.y = element_text(margin = margin(t = 0, r = 15, b = 0, l = 0))) + 
  stat_summary(fun.y = median, geom = 'line', show.legend=FALSE) +

  annotate("text", x = 10, y = 50, label = "p_rnd_inf = 0.4") +
  annotate("text", x = 10, y = 37, label = "p_rnd_inf = 0.2") +
  annotate("text", x = 10, y = 22, label = "p_rnd_inf = 0.05") +
  annotate("text", x = 10, y = 13, label = "p_rnd_inf = 0.01") 
ggsave(filename = paste0(dir,"/sensitivity_new-t3-prob_rnd_inf.png"), width = 6, height = 6)