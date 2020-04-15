# covid19 in Vo' Euganeo (or anywhere else)

A tentative multi-level network based SEIR model of the progression of the COVID19 infection.

## The model

### Agents

The population of Vo' is imported in the model upon setup. Agent attributes are _age_ and _marital status_ (source: http://demo.istat.it/pop2019/index3.html). 

### Networks

Agents in the model belong to three intertwined networks: 'household', 'relation' and 'friendship' 

A **household** structure is created as follows: married males and females are linked together on the basis of age distance, single people below the age of 26 are assumed to live at home with one or two parents and siblings. Single people above the age of 26 are assumed to live on their own, a certain proportion cohabiting. Links of type 'household' are built among these people.

A **friendship** network is created among all agents > 12 y.o. based on the *preferential attachment* principle, so that a scale-free network is produced. Friendships are skewed towards people of the same age group.

*(TODO)* A 'relation' network links people who are related but don't live in the same household

### Infection

The infection is assumed to follow social links. Only people in an infected agent's social network are exposed. When someone becomes infected, after a period of incubation, she starts infecting people in her network. 

The progression of the disease is based on data from China and Italy. Agents have a probability of developing symptoms after incubation, based on their age; another probability of worsening; another of dying. These can be modified editing the first four functions at the top of the 'Code' section in Netlogo.

### Lockdown

The model implements lockdown policies based on the response of nearly all European countries. In a lockdown all _friendship_ links are dropped (= no one can be infected through their friends). Crucially, agents are assumed to be segregating at home, therefore household members are still susceptible to the infection.

## Model configuration

The model can be configured changing the transition probabilities and timings at the beginning of the Code section in Netlogo and the following parameters in Netlogo's interface:

| Parameter 		      | Description
| --------------------------- | ------------------------------------------------------------ |
| infection-chance            | Daily probability of infecting a subset of one infected person's network |
| recovery-chance             | daily probability of recovering after average-recovery-time is reached |
| incubation-days             | days before an infected agent becomes infectious and may show symptoms |
| average-isolation-tendency  | probability of self-isolating after displaying symptoms      |
| initial-links-per-age-group | No. of random friendship links within each group upon initialization |
| use-network?                | If false contagion happens randomly                          |
| show-layout?                | Display the whole social network stricture. **WARNING: VERY SLOW** |
| lockdown-at-first-death     | Implement a full lockdown upon the first reported death (as happened in Vo' Euganeo) |
|                             |                                                              |

## The Vo' Euganeo case

In the town of Vo' Euganeo, in the province of Padua, Italy, the first official death from COVID19 was recorded. Immediately afterwards, a lockdown of the whole town was ordered and 85% of the whole population of 3300 was tested. Nearly 3% was found to be carrying the Coronavirus. Twelve days later a second death was recorded.
