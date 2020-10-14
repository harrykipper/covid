dir<-"~/ownCloud/abm/presentations/"
ind<-read.csv("results/new_deal_ind.csv.xz")
covid<-read.csv("results/new_deal.csv")
ind$testsPerSick<-ind$tests/ind$infected

covid_high<-covid[covid$pctApp=="0",]
covid_high$compliance<-"High"
covid_high$run<-covid_high$run + 10000  
covid<-rbind(covid,covid_high)

ind_high<-ind[ind$pctApp=="0",]
ind_high$compliance<-"High"
ind_high$run<-ind_high$run + 10000
ind<-rbind(ind,ind_high)


############ Linear model ################# 
covid<-covid[covid$pctTest<100,]
attach(covid)

p<-lm(propInfected ~ pctApp + pctTest + SymPriority + compliance)
m<-lm(deaths ~ pctApp + pctTest + SymPriority + compliance)
summary(p)
summary(m)


#################### Boxplots ###################################

cols<-c("#c6c100","#a1dab4","#41b6c4","#2c7fb8","#253494")
library(ggplot2)

covid<-covid[covid$schools=="true",]
ind<-ind[ind$schools=="true",]


covid$pctApp<-as.factor(covid$pctApp)
covid$pctTest<-as.factor(covid$pctTest)

for(c in unique(covid$compliance)){
  for(p in unique(covid$SymPriority)){
    ggplot(covid[covid$SymPriority==p & covid$compliance==c,],
       aes(x=pctTest,y=propInfected,fill=pctApp)) +
    geom_boxplot(show.legend=FALSE) +
    scale_fill_brewer(type = "seq",palette = "YlGnBu")+
    labs(x="Tests per week (% of population)",y="% infected",fill="CTA adoption (%)",
      title = paste0("Schools open; compliance: ",c,"; priority to symptomatics: ",p)
      ) +
    scale_x_discrete (labels=c("0","0.5","1","1.5","3","6","∞"))+
    #ylim(c(24,52)) +
    theme_bw() +
    theme(axis.text = element_text(size = 15),
          axis.title = element_text(size=16),
          legend.text = element_text(size=16),
          
          axis.title.x = element_text(margin = margin(t = 15, r = 0, b = 0, l = 0)),
          axis.title.y = element_text(margin = margin(t = 0, r = 15, b = 0, l = 0))
          
          
          )
    ggsave(filename = paste0(dir,"/new_deal-box-comp_",c,"-prio_",p,".png"), width = 9, height = 6)
  }
}

#############################################################
## Select cases with median propInfected for every combination tested.
x<-NULL
i<-1
meds<-NULL
for(a in unique(covid$pctApp)){
  for(t in unique(covid$pctTest)){
    for(c in unique(covid$compliance)){
      for(p in unique(covid$SymPriority)){
        this<-covid[covid$run %in% unique(covid[covid$compliance == c & covid$SymPriority==p & covid$pctApp==a & covid$pctTest==t,]$run),]
        this$diff<-apply(this[c("propInfected")], 1, function (q) abs(q - median(this$propInfected)))
        this<-this[order(this$diff),]
        meds<-rbind(meds,this[1,])
        x[i]<-this[1,]$run
        i<-i+1
      }
    }
  }
}
ind<-ind[ind$run %in% x,]

##########################################################
# Plot the epidemic course of selected individual runs
##########################################################

covid_plot<-ind[ind$pctTest==1.5 & ind$compliance == "Low" & ind$SymPriority == "true",]
covid_plot$pctApp<-factor(covid_plot$pctApp) 

ggplot(covid_plot, aes(x=t,y=((infected / 102908) * 100), color=pctApp)) + # / 102908) * 100), color=run)) +
#ggplot(covid_plot, aes(x=t,y=((positiveTests/tests) * 100), color=pctApp)) + # / 102908) * 100), color=run)) +
#ggplot(covid_plot, aes(x=t,y=(((recovered + dead) / 102908) * 100), color=pctApp)) + # / 102908) * 100), color=run)) +
  geom_line(size=2) + #, show.legend=FALSE) +
  scale_colour_manual(values = cols) +
  #scale_color_brewer(type = "qual", palette = "YlGnBu") + 
  # labels = c("0","20", "40","60", "80")) +
  #ylim(0,50) +
  #ylim(0,35) +
  #scale_x_continuous(expand = c(0, 0), breaks = c(0,50,100,150,200,250,300,350,400)) + scale_y_continuous(limits=c(0,9),expand = c(0, 0)) +
  theme_minimal()+
  theme(axis.text = element_text(size = 15),axis.title = element_text(size=16),legend.text = element_text(size=16),
        axis.title.x = element_text(margin = margin(t = 15, r = 0, b = 0, l = 0)),
        axis.title.y = element_text(margin = margin(t = 0, r = 15, b = 0, l = 0)),
        axis.line = element_line(colour = "black", size = 1)
        ) +
  labs(x="Day",y="% infected",color="% CTA users", title = "Tests = 1.5%; compliance low; social distancing; priority to symptomatics") 
 theme(legend.text = element_text(size = 14),legend.position = "bottom",legend.title = element_blank(),
    axis.title = element_text(size = 14),axis.text = element_text(size = 14),legend.key.height=unit(2, "cm"))

ggsave(filename = paste0(dir,"/revised2-infected-tests_1.5-comp_low-prio_true.png"), width = 9, height = 6)

####################################
# TILE PLOT of difference in peak 
####################################

# Identify the peak of every individual run
meds$peak<-sapply(meds$run,function(q){
  max(ind[ind$run==q,]$infected)
})

# Produce a tile plot of the difference in peak over the baseline
for(c in unique(meds$compliance)){
  for(p in unique(meds$SymPriority)){
    this<-meds[meds$compliance == c & meds$SymPriority == p,]
    base<-this[this$pctApp == 0 & this$pctTest == 0,]$peak
    #this<-this[this$pctApp > 0 & this$pctTest > 0,]
    this$peakReduction<- -(((this$peak - base) / base)) 
    this<-this[c(2,3,ncol(this))]
    #this<-acast(this,pctApp ~ pctTest)
    ggplot(this,aes(x=factor(pctApp), 
                    y=factor(pctTest), 
                    fill=peakReduction)) + geom_tile(show.legend=FALSE) +
      geom_text(aes(label=round(peakReduction,digits = 2)),colour="#000000",fontface="bold", size=4)+
      scale_y_discrete (labels=c("0","0.5","1","1.5","3","6","∞")) +
      scale_fill_distiller(palette = "YlGnBu", direction = 1) +
      #theme_light() +
      theme(axis.text = element_text(size = 16),
            axis.title = element_text(size=18),
            legend.text = element_text(size=16),
            axis.title.x = element_text(margin = margin(t = 15, r = 0, b = 0, l = 0)),
            axis.title.y = element_text(margin = margin(t = 0, r = 15, b = 0, l = 0))
           ) +
      labs(x="% CTA users",y="Tests per week (% of population)",fill="infection reduction at peak") # title = paste0("Compliance: ", c, "; Priority to symptomatics: ", p)) 
    ggsave(filename = paste0(dir,"/tiles-comp_",c,"-prio_",p,".png"), width = 9, height = 6)
  }
}
