# Modelling the effectiveness of covid19 contact tracing apps 

A tentative multi-layer network agent-based model of the progression of the COVID19 infection and its mitigations

## The model

### Agents

The population of Glasgow, Scotland is imported in the model upon setup, at a 1/5 scale (120,000 agents circa). Agent attributes are _age_, _gender_, _household type_, and _location_ (source: 2011 Census). 

### Networks

Agents in the model belong to four intertwined networks: 'household', 'relation', 'friendship' and 'work'. Children between 6-17 y.o. also belong to a number of 'classroom' networks.

A **household** structure is created as follows: males and females belonging to the same household type, and residing in the same locale (detailed postcode sector), are linked together on the basis of age distance; single people below the age of 20 are assumed to live at home with one or two parents and siblings. Single people above the age of 20 are assumed to live on their own, a certain proportion cohabiting. Links of type 'household' are built among these people.

A number of **workplace** networks are created based on the distribution of workplace sizes in the city of Glasgow. Active working age agents are distributed among workplaces and linked with all co-workers, a subset of which assumed to be in closer, more frequent contact. 13% of working age agents are assigned to public-facing employment, entailing frequent contact with other agents. 

A **friendship** network is created among all agents > 14 y.o. based on the *preferential attachment* principle, so that a scale-free network is produced. Friendships are skewed towards people of the same age group.

A **relation** network links people who are related but don't live in the same household (i.e. grandparents)

A **classroom** network links children between 6-17 years of age in groups of maximum 30 children of the same age.

### Infection

The infection is assumed to follow _predominantly_ social links. People in an infected agent's household, social network and workplace are more exposed, due to the high frequency of contact. Random encounters are more rare. When someone becomes infected, after a period of incubation, she starts infecting people in her network. 

The progression of the disease is based on available data and research. Agents have a probability of developing symptoms after incubation, based on their age; another probability of worsening; another of dying. The probability is slightly lower for women in all three phases. 
The probabilities can be modified editing the DiseaseConfig.nls file.

![Disease progression](https://raw.githubusercontent.com/harrykipper/covid/master/infection.png)

### Lockdown

The model implements lockdown policies based on the response of nearly all European countries. In a lockdown all _friendship_ links are dropped (= no one can be infected through their friends) and schools and workplaces are closed. Crucially, agents are assumed to be segregating at home, therefore household members are still somewhat exposed to the infection.

### Social distancing

Social distancing is implemented in the model assuming a subset of workers working from home, less frequent contacts among acquaintances, smaller classrooms, and safe distance measures in public places, resulting in a reduced probability of viral transmission.

### Contact tracing 

The model simulates a proposed contact tracing strategy for the "second phase" of epidemic control: an opt-in smartphone app. Upon model initialization a certain proportion of agents are given the "app". If an agent with the app tests positive for COVID19 all other agents who have come into contact with her in the previous 10 days, and also have the app, are notified and have the option to self-segregate as a precaution.

## Model configuration

The model can be configured changing the transition probabilities and timings in DiseaseConfig.nls and the following parameters in Netlogo's interface:

| Parameter 		      | Description
| --------------------------- | ------------------------------------------------------------ |
| infection-chance            | Daily probability of infecting a subset of one infected person's network |
| initially-infected          | Proportion of the population infected on simulation day 0 |
| initially-cured	      | Proportion of the population having recovered from infection on simulation day 0 |
| average-isolation-tendency  | Probability of self-isolating after displaying symptoms      |
| lockdown-at-first-death     | Implement a full lockdown upon the first reported death  |
| pct-with-tracing-app	      | Percentage of the population carrying the contact-tracing app |
| tests-per-100-people	      | Number of tests available **per week** as proportion of the population |
| schools-open?               | Whether kids go to school each morning |
| social-distancing?	      | Whether social distancing measures are in place |
| app-compliance              | Likelihood that a non-symptomatic agent notified by the app will self-isolate | 
| use-seed                    | The simulation uses a fixed random seed |

## How to use

Download the content of the repository, and open Covid19VO.nlogo in the last version of NetLogo (https://ccl.northwestern.edu/netlogo/6.1.1/). The model is useful to show the progression of the infection and appreciate the difference in infections and casualties with and without social distancing/lockdown measures and, more importantly, to test the effectiveness of infection mitigation strategies such as contact tracing apps. Specifically, the complex interaction between the availability of testing and different levels of app adoption can be usefully explored with this model.

The model also shows that, when we assume that the viral transmission runs predominantly through one's social network, the dynamic of the infection is different from that emerging under the assumption of most SEIR models of an equal probability of everyone infecting everyone else.

The model is easy to adapt to test different levels of infectiousness and different proportions of people becoming symptomatic and severely ill. 

