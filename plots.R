dir<-"~/ownCloud/abm/presentations/"
##dir<-"C:/github_projects/covidstefano/Results"
##setwd("C:/github_projects/covidstefano/Results")
##getwd()
ind<-read.csv("lotsofrandom_ind.csv.xz")
covid<-read.csv("lotsofrandom.csv")
ind$testsPerSick<-ind$tests/ind$infected

covid_high<-covid[covid$pctApp=="0",]
covid_high$compliance<-"High"
covid_high$run<-covid_high$run + 10000  
covid<-rbind(covid,covid_high)

ind_high<-ind[ind$pctApp=="0",]
ind_high$compliance<-"High"
ind_high$run<-ind_high$run + 10000
ind<-rbind(ind,ind_high)

covid_prio<-covid[covid$pctTest=="0",]
covid_prio$SymPriority<-"true"
covid_prio$run<-covid_prio$run + 10000
covid<-rbind(covid,covid_prio)

ind_prio<-ind[ind$pctTest=="0",]
ind_prio$SymPriority<-"true"
ind_prio$run<-ind_prio$run + 10000
ind<-rbind(ind,ind_prio)




############ Linear model ################# 
covid<-covid[covid$pctTest<100,]
attach(covid)

p<-lm(propInfected ~ pctApp + pctTest + SymPriority + compliance)
m<-lm(deaths ~ pctApp + pctTest + SymPriority + compliance)
summary(p)
summary(m)


#################### Boxplots ###################################

##cols<-c("#c6c100","#a1dab4","#41b6c4","#2c7fb8","#253494")
cols<-c("#BFD439","#36802d","#66B2FF","#2c7fb8","#6666FF") #"#c6c100","#a1dab4","#41b6c4","#2c7fb8","#253494"
library(ggplot2)

covid<-covid[covid$schools=="true",]
ind<-ind[ind$schools=="true",]


covid$pctApp<-as.factor(covid$pctApp)
covid$pctTest<-as.factor(covid$pctTest)

for(c in unique(covid$compliance)){
  for(p in unique(covid$SymPriority)){
    my_boxplot<-ggplot(covid[covid$SymPriority==p & covid$compliance==c,],
       aes(x=pctTest,y=propInfected,fill=pctApp)) +
      geom_boxplot(show.legend=TRUE) +  #geom_boxplot
      scale_fill_brewer(type = "seq")+ #palette = "YlGnBu"
      scale_fill_manual(values=cols)+
      labs(x="Tests per week (% of population)",y="% infected",fill="CTA adoption (%)" 
           #title = paste0("Schools open; compliance: ",c,"; priority to symptomatics: ",p)
      ) +
      scale_x_discrete (labels=c("0","0.5","1","1.5","3","6",expression(infinity)))+
         scale_y_continuous( limits=c(20,55), breaks =c(20,25,30,35,40,45,50,55), minor_breaks=NULL) + ##ylim(c(20,55)) +
      theme_bw() +
      theme(axis.text = element_text(size = 22, colour="black",family = "serif" ),
            axis.title = element_text(size=28, face="bold", family = "serif"),
            legend.text = element_text(size=16),
            
            axis.title.x = element_text(margin = margin(t = 15, r = 0, b = 0, l = 0)),
            axis.title.y = element_text(margin = margin(t = 0, r = 15, b = 0, l = 0)),
            panel.grid = element_line(color="gray"),
            panel.background = element_rect(fill="#ECE7E7"),
            panel.border = element_rect(color="black", size=1, linetype="solid")
              
      )
    
    print(my_boxplot)
    ggsave(filename = paste0(dir,"/new_deal-box-comp_",c,"-prio_",p,".png"), width = 9, height = 6)
  }
}

########################alternative boxplot###########################
cols<-c("#BFD439","#36802d","#66B2FF","#2c7fb8","#6666FF") #"#c6c100","#a1dab4","#41b6c4","#2c7fb8","#253494"
library(ggplot2)

covid<-covid[covid$schools=="true",]
ind<-ind[ind$schools=="true",]


covid$pctApp<-as.factor(covid$pctApp)
covid$pctTest<-as.factor(covid$pctTest)

covid$pctTest <- factor(covid$pctTest, levels = c("0","0.5","1","1.5","3","6","100"), 
                  labels = c("0","0.5%","1%","1.5%","3%","6%","Unlimited"))
head(covid)
for(c in unique(covid$compliance)){
  for(p in unique(covid$SymPriority)){
    my_boxplot<-ggplot(covid[covid$SymPriority==p & covid$compliance==c,],
                       aes(y=propInfected,fill=pctApp)) + ##x=pctTest
      geom_boxplot(show.legend=TRUE) +  #geom_boxplot
      facet_wrap(~pctTest, ncol =7, switch = "x") +##expression(infinity)
      scale_fill_brewer(type = "seq")+ #palette = "YlGnBu"
      scale_fill_manual(values=cols)+
      labs(x="Tests per week (% of population)",y="% infected",fill="CTA adoption (%)" 
           #title = paste0("Schools open; compliance: ",c,"; priority to symptomatics: ",p)
      ) +
      ##scale_x_discrete (labels=c("0","0.5","1","1.5","3","6",expression(infinity)))+
      scale_y_continuous( limits=c(10,45), breaks =c(10,15,20,25,30,35,40,45,50,55), minor_breaks=NULL) + ##ylim(c(20,55)) +
      theme_bw() +
      theme(axis.text.y  = element_text(size = 22, colour="black",family = "serif" ),
            axis.title = element_text(size=28,family = "serif",color="black"), ##face="bold"
            legend.text = element_text(size=16),
            axis.text.x=element_blank(),
            axis.ticks.x=element_blank(),
            strip.text.x = element_text(size = 18, color = "black", family = "serif" ), ##"serif"
            axis.title.x = element_text(margin = margin(t = 15, r = 0, b = 0, l = 0)),
            axis.title.y = element_text(margin = margin(t = 0, r = 15, b = 0, l = 0)),
            panel.grid.major.y = element_line(color="gray"),
            panel.grid.major.x = element_blank(),
            panel.background = element_rect(fill="#ECE7E7"),
            panel.border = element_rect(color="black", size=1, linetype="solid"),
            panel.spacing = unit(0.2, "lines")
            
      )
    
    print(my_boxplot)
    ggsave(filename = paste0(dir,"/new_deal-box-comp_",c,"-prio_",p,".png"), width = 12, height = 6)
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

covid_plot<-ind[ind$pctTest==1.5 & ind$compliance == "High" & ind$SymPriority == "true",]
covid_plot$pctApp<-factor(covid_plot$pctApp) 

my_epi<-ggplot(covid_plot, aes(x=t,y=((infected / 102908) * 100), color=pctApp)) + # / 102908) * 100), color=run)) +
#ggplot(covid_plot, aes(x=t,y=((positiveTests/tests) * 100), color=pctApp)) + # / 102908) * 100), color=run)) +
#ggplot(covid_plot, aes(x=t,y=(((recovered + dead) / 102908) * 100), color=pctApp)) + # / 102908) * 100), color=run)) +
  geom_line(size=1.5) + #, show.legend=FALSE) +
  scale_colour_manual(values = cols) +
  #scale_color_brewer(type = "qual", palette = "YlGnBu") + 
  # labels = c("0","20", "40","60", "80")) +
  #ylim(0,50) +
  #ylim(0,35) +
  scale_x_continuous(expand = c(0, 0), limits=c(0,300), breaks = c(0,50,100,150,200,250,300)) + 
  scale_y_continuous(limits=c(0,7),expand = c(0, 0),breaks = c(0,1,2,3,4,5,6,7)) +
  
  theme_minimal()+
  theme(axis.text = element_text(size=22, family = "serif", color="Black"),axis.title = element_text(size=28, color= "black", family = "serif"),
        legend.text = element_text(size=16),
        axis.title.x = element_text(margin = margin(t = 15, r = 0, b = 0, l = 0)),
        axis.title.y = element_text(margin = margin(t = 0, r = 15, b = 0, l = 0)),
        axis.line = element_line(colour = "black", size = 1),
        panel.grid = element_line(color="lightgray"),
        panel.border = element_rect(colour = "black", fill=NA, size=1)
        ) +
  labs(x="Day",y="% infected",color="% CTA users", title = "Tests = 1.5%; compliance High; social distancing; priority to symptomatics") 
 theme(legend.text = element_text(size = 14),legend.position = "bottom",legend.title = element_blank(),
    axis.title = element_text(size = 14),axis.text = element_text(size = 14),legend.key.height=unit(2, "cm"))
print(my_epi)
ggsave(filename = paste0(dir,"/revised2-infected-tests_1.5-comp_high-prio_true.png"), width = 9, height = 6)

####################################
# TILE PLOT of difference in peak 
####################################

# Identify the peak of every individual run
meds$peak<-sapply(meds$run,function(q){
  max(ind[ind$run==q,]$infected)
})
head(meds)
# Produce a tile plot of the difference in peak over the baseline
for(c in unique(meds$compliance)){
  for(p in unique(meds$SymPriority)){
    this<-meds[meds$compliance == c & meds$SymPriority == p,]
    base<-this[this$pctApp == 0 & this$pctTest == 0,]$peak
    #this<-this[this$pctApp > 0 & this$pctTest > 0,]
    this$peakReduction<- round(100*(base -this$peak) / base)
    ##this[this$pctTest ==0, "peakReduction"]<-0 
    this<-this[c(5,6,ncol(this))]
    this<-this[this$pctTest !=0,]  ##ONLY USE RESULTS WHEN TESTING (WITH NO TESTING THE APP DO NOT WORK)
    #this<-acast(this,pctApp ~ pctTest)
    plot_tile<-ggplot(this,aes(x=factor(pctApp), 
                    y=factor(pctTest), 
                    fill=peakReduction)) + geom_tile(show.legend=FALSE) +
      geom_text(aes(label=round(peakReduction,digits = 2)),colour="#000000",fontface="bold", size=6)+
      scale_y_discrete (labels=c("0.5","1","1.5","3","6",expression(infinity))) + ##expression(infinity)
      scale_fill_distiller(palette = "YlGnBu", direction = 1) +
      #theme_light() +
      theme(axis.text = element_text(size = 22, colour="black",family = "serif"),
            axis.title = element_text(size=30, family = "serif"),
            legend.text = element_text(size=18),
            axis.title.x = element_text(margin = margin(t = 15, r = 0, b = 0, l = 0)),
            axis.title.y = element_text(margin = margin(t = 0, r = 15, b = 0, l = 0))
           ) +
      labs(x="% CTA users",y="Tests per week (% of population)",fill="infection reduction at peak") # title= paste0("Compliance: ", c, "; Priority to symptomatics: ", p)) 
    print(plot_tile)
    ggsave(filename = paste0(dir,"/tiles-comp_",c,"-prio_",p,".png"), width = 9, height = 9)
  }
}



