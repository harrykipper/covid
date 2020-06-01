le<-read.csv("Downloads/Lecce.csv")
merine<-le[le$Denominazione=="Lecce",]
colnames(merine)
merine[-c(1,2,11,19)]
merine<-merine[-c(1,2,11,19)]
write.csv(merine,"lecce.csv",row.names = FALSE)
merine[is.na(merine)]<-0

vo<-read.csv("ownCloud/covid/abm/vo.csv")
colnames(vo)

colnames(merine)
merine<-merine[-nrow(merine),]
merine<-merine[-c(6:8,13:15)]
