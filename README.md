# covid19 in small communities

A tentative multi-layer network agent-based model of the progression of the COVID19 infection.

## The model

### Agents

The population of Vo' Euganeo (Padua, Italy - 3300 residents) is imported in the model upon setup. Agent attributes are _age_, _gender_, and _marital status_ (source: http://demo.istat.it/pop2019/index3.html). 

### Networks

Agents in the model belong to three intertwined networks: 'household', 'relation' and 'friendship' 

A **household** structure is created as follows: married males and females are linked together on the basis of age distance, single people below the age of 26 are assumed to live at home with one or two parents and siblings. Single people above the age of 26 are assumed to live on their own, a certain proportion cohabiting. Links of type 'household' are built among these people.

A **friendship** network is created among all agents > 12 y.o. based on the *preferential attachment* principle, so that a scale-free network is produced. Friendships are skewed towards people of the same age group.

A **relation** network links people who are related but don't live in the same household (i.e. grandparents)

### Infection

The infection is assumed to follow _predominantly_ social links. People in an infected agent's household and social network are more exposed, due to the high frequency of contact. Random encounters are more rare. When someone becomes infected, after a period of incubation, she starts infecting people in her network. 

The progression of the disease is based on data from China and Italy. Agents have a probability of developing symptoms after incubation, based on their age; another probability of worsening; another of dying. The probability is slightly lower for women in all three phases. 
The probabilities can be modified editing the DiseaseConfig.nls file.

![Disease progression](https://raw.githubusercontent.com/harrykipper/covid/master/infection.png)

### Lockdown

The model implements lockdown policies based on the response of nearly all European countries. In a lockdown all _friendship_ links are dropped (= no one can be infected through their friends) and schools are closed. Crucially, agents are assumed to be segregating at home, therefore household members are still somewhat exposed to the infection.

### Contact tracing 

The model also simulates a proposed contact tracing strategy for the "second phase" of epidemic control: an opt-in smartphone app. Upon model initialization a certain proportion of agents are given the "app". If an agent with the app tests positive for COVID19 all other agents who have come into contact with her in the previous 10 days, and also have the app, are notified and have the option to self-segregate as a precaution.

## Model configuration

The model can be configured changing the transition probabilities and timings in DiseaseConfig.nls and the following parameters in Netlogo's interface:

| Parameter 		      | Description
| --------------------------- | ------------------------------------------------------------ |
| infection-chance            | Daily probability of infecting a subset of one infected person's network |
| initially-infected          | Proportion of the population infected on simulation day 0 |
| incubation-days             | Days before an infected agent becomes infectious and may show symptoms |
| average-isolation-tendency  | Probability of self-isolating after displaying symptoms      |
| use-network?                | If false contagion happens randomly                          |
| initial-links-per-age-group | No. of random friendship links within each group upon initialization |
| show-layout?                | Display the whole social network stricture. **WARNING: VERY SLOW** |
| lockdown-at-first-death     | Implement a full lockdown upon the first reported death (as happened in Vo' Euganeo) |
| pct-with-tracing-app	      | Percentage of the population carrying the contact-tracing app |
| tests-per-100-people	      | Number of tests available **per week** as proportion of the population |
| schools-open?               | Whether kids go to school each morning |
| use-seed                    | The simulation uses a fixed random seed |
| use-existing-nw             | Use a pre-made social network instead of creating one at setup (much faster) |

## What to do with this

The model is useful to show the progression of the infection in a small community and appreciate the difference in infections and casualties with and without social distancing/lockdown measures, and to test the effectiveness of infection mitigation strategies such as contact tracing apps.

The model also shows that, when we assume that the viral transmission runs predominantly through one's social network, the dynamic of the infection is different from that emerging under the assumption of most SEIR models of an equal probability of everyone infecting everyone else.

The model is easy to adapt to test different levels of infectiousness and different proportions of people becoming symptomatic and severely ill. 

## References

* https://www.scribd.com/document/450608044/Coronavirus-Regione-Veneto-Azienda-Zero-pdf
* https://www.medrxiv.org/content/10.1101/2020.04.17.20053157v1

## The Vo' Euganeo case

The first official Italian COVID19 death was a 78 year old resident of the town of Vo' Euganeo, in the province of Padua, on February 22. Immediately afterwards, a lockdown of the whole town was ordered and 85% of the whole population of 3300 was tested. Nearly 3% was found to be carrying the Coronavirus (https://www.scribd.com/document/450608044/Coronavirus-Regione-Veneto-Azienda-Zero-pdf). Eighteen days later a second death was recorded in the town, a 68 year old, who was a friend of the first victim.
