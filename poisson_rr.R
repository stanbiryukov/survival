## Stan Biryukov
## Show equivalency between estimates of relative risks from Cox model and poisson log-link model on discrete survival data
library(survival)
library(data.table)
library(splitstackshape)
data(ovarian)
cox_m <- coxph(Surv(time = futime,event = fustat) ~ age + rx,data=ovarian,ties=c("breslow"))
summary(cox_m)
summary(cox_m)$coeff["rx","exp(coef)"] ## rx = 0.4475473
summary(cox_m)$coeff["age","exp(coef)"] ## age = 1.158732
## now the discrete survival model
setDT(ovarian)[, id := 1:.N]
pp <- expandRows(ovarian, "futime")
setDT(pp)[, period := 1:.N, by = id]
setDT(pp)[, N :=.N, by = id]
pp$y=0
pp$y = ifelse(pp$fustat==1 & pp$period==pp$N,1,pp$y)
logs_m <- glm(y ~ age + rx + as.factor(period), data = pp, family=poisson())
exp(coef(logs_m)["rx"][[1]]) ## rx = 0.4475473
exp(coef(logs_m)["age"][[1]]) ## age = 1.158732
