extensions [csv]

undirected-link-breed [spouses spouse]
undirected-link-breed [households household]
undirected-link-breed [relations relation]
undirected-link-breed [friendships friendship]

globals
[
  nb-infected-previous ;; Number of infected people at the previous tick
  border               ;; The patches representing the yellow border
  in-hospital          ;; Number of people currently in hospital
  hospital-beds        ;; Number of places in the hospital
  angle                ;; Heading for individuals
  beta-n               ;; The average number of new secondary infections per infected this tick
  gamma                ;; The average number of new recoveries per infected this tick
  r0                   ;; The number of secondary infections that arise due to a single infective introduced in a wholly susceptible population
]

turtles-own
[
  sex
  age
  status               ;; marital status
  infected?            ;; If true, the person is infected.
  cured?               ;; If true, the person has lived through an infection. They cannot be re-infected.
  symptomatic?         ;; If true, the person is showing symptoms of infection
  severe-symptoms?     ;; If true, the person is showing severe symptoms
  isolated?            ;; If true, the person is isolated, unable to infect anyone.
  hospitalized?        ;; If true, the person is hospitalized and will recovery in half the average-recovery-time.
  dead?                ;; If true, the person is... you know..


  infection-length     ;; How long the person has been infected.
  recovery-time        ;; Time (in days) it takes before the person has a chance to recover from the infection
  symptom-time         ;; Time (in days) it takes before the person shows symptoms
  deterioration-time   ;; Time (in days) it takes before a symptomatic person deteriorates
  prob-symptoms        ;; Probability that the person is symptomatic
  isolation-tendency   ;; Chance the person will self-quarantine during any hour being infected.

  susceptible?         ;; Tracks whether the person was initially susceptible
  nb-infected          ;; Number of secondary infections caused by an infected person at the end of the tick
  nb-recovered         ;; Number of recovered people at the end of the tick
]

links-own [meanage removed?]

;;;
;;; SETUP PROCEDURES
;;;

to setup
  clear-all
  set-default-shape turtles "circle"

  read-agents
  set N-people count turtles

  create-hh

  make-initial-links
  create-friendships
  ask links [set removed? false]
  if show-layout [repeat 50 [layout]]

  reset-ticks

  ask one-of turtles with [age >= 49 and age <= 74 and sex = "M"][
    set infected? true
    set susceptible? false
  ]
end

to read-agents
  let row 0
  foreach csv:from-file "vo.csv" [ag ->
    let i 1
    if row > 0 [
      while [i < length ag][
        crt item i ag [

          set cured? false
          set isolated? false
          set hospitalized? false
          set infected? false
          set susceptible? true
          set symptomatic? false
          set severe-symptoms? false
          set dead? false

          set age item 0 ag + 1 ;; Data are from 2019, everyone is one year older now...
          ; show (word "DEBUG: Creating agents of age " item 0 ag)
          ifelse i < 5 [set sex "M"][set sex "F"]
          ifelse i = 1 or i = 5 [set status 0][
            ifelse i = 2 or i = 6 [set status 1][
              ifelse i = 3 or i = 7 [set status 2][
                ifelse i = 4 or i = 8 [set status 3][set status 4]
              ]
            ]
          ]
        ]
        set i i + 1
      ]
    ]
    set row row + 1
  ]
end

to lockdown
  ask friendships [set removed? true]
  ask relations [set removed? true]
end

to create-hh
  create-marriages
  if show-layout [repeat 50 [layout]]
  attach-children
  ;repeat count turtles with [status = 0] / 2 [layout]
  if show-layout [repeat 50 [layout]]
end

;to create-marriages
;  ask turtles with [sex = "F" and status = 1][
;    let age-interval-min age - 8
;    let age-interval-max age + 14
;    create-household-with one-of turtles with [
;      sex = "M" and
;      status = 1 and
;      age <= age-interval-max and age >= age-interval-min and
;      count my-households = 0
;    ]
;  ]
;end

to create-marriages
  ask turtles with [sex = "F" and status = 1][
    let pretendenti turtles with [
      sex = "M" and
      status = 1 and
      count my-spouses = 0
    ]
    let marito min-one-of pretendenti [abs (age - [age] of myself)]
    create-spouse-with marito
    move-to marito
    fd 8
  ]
end

to attach-children
  ask turtles with [
    age < 29 and
    status = 0
  ][
    let age-interval-min age + 24
    let age-interval-max age + 36
    let thekid self
    ask one-of turtles with [
      status != 0 and
      sex = "M" and
      age <= age-interval-max and age >= age-interval-min
    ]
    [
      if any? my-spouses [ask spouse-neighbors [create-household-with thekid]]
      ifelse any? my-households [
        ask my-households [ask both-ends [create-household-with thekid]]
      ][create-household-with thekid]
    ]
  ]
  if show-layout [layout]
end

to create-relations
  ; not there yet ;-)
end

to create-friendships
  ask turtles with [age >= 12][
    repeat 2 + random 10 [create-friendship-with find-partner]
  ]
  if show-layout [layout]
end

to-report probability-of-showing-symptoms [agent-age]
  report (ifelse-value
    agent-age < 30 [10]
    agent-age < 40 [20]
    agent-age < 50 [40]
    agent-age < 60 [70]
    [85]
  )
end

to-report probability-of-worsening [agent-age]
  report (ifelse-value
    agent-age < 40 [5]
    agent-age < 50 [10]
    agent-age < 60 [25]
    [40]
  )
end

to-report probability-of-dying [agent-age]
  report (ifelse-value
    agent-age < 40 [10]
    agent-age < 50 [20]
    agent-age < 60 [30]
    [50]
  )
end

to-report average-recovery-time [agent-age]
  report (ifelse-value
    agent-age < 30 [5]
    agent-age < 40 [9]
    agent-age < 50 [12]
    agent-age < 60 [16]
    [20]
    )
end

to assign-tendency ;; Turtle procedure

  set isolation-tendency random-normal average-isolation-tendency average-isolation-tendency / 4
  set recovery-time random-normal (average-recovery-time age) (average-recovery-time age / 4)
  set symptom-time random-normal avg-days-for-symptoms avg-days-for-symptoms / 2
  set prob-symptoms probability-of-showing-symptoms age
  set deterioration-time symptom-time + random-normal 5 1

  ;; Make sure recovery-time lies between 0 and 2x average-recovery-time
  if recovery-time > (average-recovery-time age) * 2 [ set recovery-time (average-recovery-time age) * 2 ]
  if recovery-time < 0 [ set recovery-time 0 ]

  ;; Similarly for isolation and hospital going tendencies
  if isolation-tendency > average-isolation-tendency * 2 [ set isolation-tendency average-isolation-tendency * 2 ]
  if isolation-tendency < 0 [ set isolation-tendency 0 ]
end


;; Different people are displayed in 5 different colors depending on health
;; green is a survivor of the infection
;; blue is a successful innoculation
;; red is an infected person
;; white is neither infected, innoculated, nor cured

to assign-color ;; turtle procedure
  ifelse cured?
    [ set color green ]
      [ ifelse infected?
        [set color red ]
        [set color white]]
end

;;;
;;; GO PROCEDURES
;;;

to go
  if all? turtles [ not infected? ][ stop ]
  ask turtles
    [ clear-count ]

  ask turtles
    [ if infected? and not isolated? and not hospitalized?
         [ infect ] ]

  ask turtles
    [ if not isolated? and not hospitalized? and infected? and symptomatic? and (random 100 < isolation-tendency)
        [ isolate ] ]

  ask turtles
    [ if not isolated? and not hospitalized? and infected? and severe-symptoms?
      [ hospitalize] ]

  ask turtles
    [ if infected?
      [
        set infection-length infection-length + 1
        if severe-symptoms? and infection-length = deterioration-time * 2 [maybe-die]
        if symptomatic? and not severe-symptoms? and infection-length = deterioration-time [maybe-worsen]
        if not symptomatic? and infection-length = symptom-time [maybe-show-symptoms]
        maybe-recover
      ]
  ]

  ask turtles
    [ if (isolated? or hospitalized?) and cured?
        [ unisolate ] ]

  ask turtles
    [ assign-color
      calculate-r0 ]

  tick
end

to clear-count
  set nb-infected 0
  set nb-recovered 0
end

to maybe-show-symptoms
  if prob-symptoms > random 100 [set symptomatic? true]
end

to maybe-worsen
  if probability-of-worsening age > random 100 [set severe-symptoms? true]
end

to maybe-die
  ifelse hospitalized?
  [if probability-of-dying age > random 100 [kill-agent]]
  [if probability-of-dying age * 1.5 > random 100 [kill-agent]]
end

to kill-agent
  ask my-links [die]
  set dead? true
end

to maybe-recover
  ;; If people have been infected for more than the recovery-time
  ;; then there is a chance for recovery
  if infection-length > recovery-time [
    if random-float 100 < recovery-chance [
      set infected? false
      set cured? true
      set nb-recovered (nb-recovered + 1)
      if hospitalized? [set in-hospital in-hospital - 1]
    ]
  ]
end

;; To better show that isolation has occurred, the patch below the person turns gray
to isolate ;; turtle procedure
  set isolated? true
  ask my-friendships [set removed? true]
  ask my-relations [set removed? true]
  set pcolor grey
end

;; After unisolating, patch turns back to normal color
to unisolate  ;; turtle procedure
  set isolated? false
  set hospitalized? false
  ask my-links with [removed? = true][set removed? false]
end

;; To hospitalize, remove all links. Recovery time increases, as the matter is serious.
to hospitalize ;; turtle procedure
  set hospitalized? true
  set in-hospital in-hospital + 1
  set recovery-time recovery-time * 2
  set pcolor black
  move-to patch (max-pxcor / 2) 0
  ask my-links [set removed? true]
  set pcolor white
end

to newinfection
  set infected? true
  set symptomatic? false
  set severe-symptoms? false
  set nb-infected (nb-infected + 1)
end

;; Infected individuals who are not isolated or hospitalized have a chance of transmitting
;; their disease to their susceptible neighbors.
;; If the neighbor is linked, then the chance of disease transmission doubles.

to infect  ;; turtle procedure
  let caller self
  let nearby-uninfected (link-neighbors) with [not infected? and not cured?]

  if nearby-uninfected != nobody
    [
      ask nearby-uninfected
        [
          ifelse household-neighbor? caller or spouse-neighbor? caller
            [
              if random 100 < infection-chance * 4 ;; twice as likely to infect a linked person
              [newinfection]
          ]
          [
            if not [removed?] of link-with caller [
              if random 100 < infection-chance
              [newinfection]
            ]
          ]
      ]
  ]
end


to calculate-r0

  let new-infected sum [ nb-infected ] of turtles
  let new-recovered sum [ nb-recovered ] of turtles
  set nb-infected-previous (count turtles with [ infected? ] + new-recovered - new-infected)  ;; Number of infected people at the previous tick
  let susceptible-t (N-people - (count turtles with [ infected? ]) - (count turtles with [ cured? ]))  ;; Number of susceptibles now
  let s0 count turtles with [ susceptible? ] ;; Initial number of susceptibles

  ifelse nb-infected-previous < 10
  [ set beta-n 0 ]
  [
    set beta-n (new-infected / nb-infected-previous)       ;; This is the average number of new secondary infections per infected this tick
  ]

  ifelse nb-infected-previous < 5
  [ set gamma 0 ]
  [
    set gamma (new-recovered / nb-infected-previous)     ;; This is the average number of new recoveries per infected this tick
  ]

  if ((N-people - susceptible-t) != 0 and (susceptible-t != 0))   ;; Prevent from dividing by 0
  [
    ;; This is derived from integrating dI / dS = (beta*SI - gamma*I) / (-beta*SI)
    ;; Assuming one infected individual introduced in the beginning, and hence counting I(0) as negligible,
    ;; we get the relation
    ;; N - gamma*ln(S(0)) / beta = S(t) - gamma*ln(S(t)) / beta, where N is the initial 'susceptible' population.
    ;; Since N >> 1
    ;; Using this, we have R_0 = beta*N / gamma = N*ln(S(0)/S(t)) / (K-S(t))
    set r0 (ln (s0 / susceptible-t) / (N-people - susceptible-t))
    set r0 r0 * s0 ]
end

;; make the initial network of initial-links-per-age-group edges per age group
to make-initial-links
  foreach (list [6 10][11 14][15 19][20 25][26 36][37 49][50 65][66 80][81 103]) [a-g ->
    repeat initial-links-per-age-group [
      ask one-of turtles with [age >= item 0 a-g and age <= item 1 a-g] [
        create-friendship-with one-of other turtles with [age >= item 0 a-g and age <= item 1 a-g] [
          set color green
          set meanage mean [age] of both-ends
        ]
      ]
    ]
  ]
end

;; This code is the heart of the "preferential attachment" mechanism, and acts like
;; a lottery where each node gets a ticket for every connection it already has.
;; While the basic idea is the same as in the Lottery Example (in the Code Examples
;; section of the Models Library), things are made simpler here by the fact that we
;; can just use the links as if they were the "tickets": we first pick a random link,
;; and than we pick one of the two ends of that link.
to-report find-partner
  let partner nobody
  let connection one-of friendships with [abs ([age] of myself - meanage) <= 12]
  ifelse age >= 25 [
    if random 100 <= 15 [set connection one-of friendships]
  ][ifelse age >= 15
    [set connection one-of friendships with [meanage - [age] of myself <= 8]]
    [if age > 12 [set connection one-of friendships with [meanage - [age] of myself <= 5]]]
  ]
  ask connection [
    ifelse member? myself both-ends
    [set partner other-end]
    [set partner one-of both-ends]
  ]
  report partner
end

;;;;;;;;;;;;;;
;;; Layout ;;;
;;;;;;;;;;;;;;

;; resize-nodes, change back and forth from size based on degree to a size of 1
to resize-nodes
  ifelse all? turtles [size <= 1]
  [
    ;; a node is a circle with diameter determined by
    ;; the SIZE variable; using SQRT makes the circle's
    ;; area proportional to its degree
    ask turtles [ set size sqrt count link-neighbors ]
  ]
  [
    ask turtles [ set size 1 ]
  ]
end

to layout
  ;; the number 3 here is arbitrary; more repetitions slows down the
  ;; model, but too few gives poor layouts
  repeat 3 [
    ;; the more turtles we have to fit into the same amount of space,
    ;; the smaller the inputs to layout-spring we'll need to use
    let factor sqrt count turtles
    ;; numbers here are arbitrarily chosen for pleasing appearance
    layout-spring turtles links (1 / factor) (7 / factor) (1 / factor)
    display  ;; for smooth animation
  ]
  ;; don't bump the edges of the world
  let x-offset max [xcor] of turtles + min [xcor] of turtles
  let y-offset max [ycor] of turtles + min [ycor] of turtles
  ;; big jumps look funny, so only adjust a little each time
  set x-offset limit-magnitude x-offset 0.1
  set y-offset limit-magnitude y-offset 0.1
  ask turtles [ setxy (xcor - x-offset / 2) (ycor - y-offset / 2) ]
end

to-report limit-magnitude [number limit]
  if number > limit [ report limit ]
  if number < (- limit) [ report (- limit) ]
  report number
end
@#$#@#$#@
GRAPHICS-WINDOW
646
27
1659
1041
-1
-1
5.0
1
10
1
1
1
0
0
0
1
-100
100
-100
100
1
1
1
day
30.0

BUTTON
320
105
403
138
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
424
105
507
138
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SLIDER
18
22
287
55
N-people
N-people
50
4000
3304.0
10
1
NIL
HORIZONTAL

SLIDER
315
22
584
55
average-isolation-tendency
average-isolation-tendency
0
50
5.0
5
1
NIL
HORIZONTAL

PLOT
356
299
619
442
Populations
hours
# people
0.0
10.0
0.0
350.0
true
true
"" ""
PENS
"Infected" 1.0 0 -2674135 true "" "plot count turtles with [ infected? ]"
"Susceptible" 1.0 0 -10899396 true "" "plot count turtles with [ not infected? and not cured? ]"
"Recovered" 1.0 0 -7500403 true "" "plot count turtles with [ cured? ]"
"Dead" 1.0 0 -16777216 true "" "plot count turtles with [dead?]"

PLOT
11
452
344
597
Infection and Recovery Rates
hours
rate
0.0
10.0
0.0
0.1
true
true
"" ""
PENS
"Infection Rate" 1.0 0 -2674135 true "" "plot (beta-n * nb-infected-previous)"
"Recovery Rate" 1.0 0 -10899396 true "" "plot (gamma * nb-infected-previous)"

SLIDER
18
59
286
92
infection-chance
infection-chance
10
100
55.0
5
1
NIL
HORIZONTAL

SLIDER
18
97
285
130
recovery-chance
recovery-chance
10
100
45.0
5
1
NIL
HORIZONTAL

MONITOR
356
451
437
496
R0
r0\n
2
1
11

PLOT
11
297
343
441
Cumulative Infected and Recovered
hours
% total pop.
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"% infected" 1.0 0 -2674135 true "" "plot (((count turtles with [ cured? ] + count turtles with [ infected? ]) / N-people) * 100)"
"% recovered" 1.0 0 -9276814 true "" "plot ((count turtles with [ cured? ] / N-people) * 100)"

SLIDER
315
60
532
93
initial-links-per-age-group
initial-links-per-age-group
0
10
4.0
1
1
NIL
HORIZONTAL

PLOT
15
695
305
913
Degree distribution (log-log)
log(degree)
log(#of nodes)
0.0
0.3
0.0
0.3
true
false
"" ""
PENS
"default" 1.0 2 -16777216 true "" "let max-degree max [count friendship-neighbors] of turtles\n;; for this plot, the axes are logarithmic, so we can't\n;; use \"histogram-from\"; we have to plot the points\n;; ourselves one at a time\nplot-pen-reset  ;; erase what we plotted before\n;; the way we create the network there is never a zero degree node,\n;; so start plotting at degree one\nlet degree 1\nwhile [degree <= max-degree] [\n  let matches turtles with [count friendship-neighbors = degree]\n  if any? matches\n    [ plotxy log degree 10\n             log (count matches) 10 ]\n  set degree degree + 1\n]"

PLOT
311
694
601
914
Degree distribution
NIL
NIL
1.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "let max-degree max [count friendship-neighbors] of turtles\nplot-pen-reset  ;; erase what we plotted before\nset-plot-x-range 1 (max-degree + 1)  ;; + 1 to make room for the width of the last bar\nhistogram [count friendship-neighbors] of turtles"

SWITCH
15
185
147
218
show-layout
show-layout
1
1
-1000

SLIDER
15
145
217
178
avg-days-for-symptoms
avg-days-for-symptoms
0
14
6.0
1
1
NIL
HORIZONTAL

BUTTON
395
155
507
188
LOCKDOWN!
lockdown
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
135
655
490
711
====== \"Friendship\" network ======
20
0.0
1

@#$#@#$#@
## WHAT IS IT?

This model is an extension of the basic model of epiDEM (a curricular unit which stands for Epidemiology: Understanding Disease Dynamics and Emergence through Modeling). It simulates the spread of an infectious disease in a semi-closed population, but with additional features such as travel, isolation, quarantine, inoculation, and links between individuals. However, we still assume that the virus does not mutate, and that upon recovery, an individual will have perfect immunity.

Overall, this model helps users:
1) understand the emergent disease spread dynamics in relation to the changes in control measures, travel, and mobility
2) understand how the reproduction number, R_0, represents the threshold for an epidemic
3) understand the relationship between derivatives and integrals, represented simply as rates and cumulative number of cases, and
4) provide opportunities to extend or change the model to include some properties of a disease that interest users the most.

## HOW IT WORKS

Individuals wander around the world in random motion. There are two groups of individuals, represented as either squares or circles, and are geographically divided by the yellow border. Upon coming into contact with an infected person, he or she has a chance of contracting the illness. Depending on their tendencies, which are set by the user, sick individuals will either isolate themselves at "home," go to a hospital, be force-quarantined into a hospital by health officials, or just move about. An infected individual has a chance of recovery after the given recovery time has elapsed.

The presence of the virus in the population is represented by the colors of individuals. Four colors are used: white individuals are uninfected, red individuals are infected, green individuals are recovered, and blue individuals are inoculated. Once recovered, the individual is permanently immune to the virus. The yellow person symbolizes the health official or ambulance, who patrols the world in search of ill people. Once coming in contact with an infected individual, the ambulance immediately delivers the infected to the hospital within the region of residence.

The graph INFECTION AND RECOVERY RATES shows the rate of change of the cumulative infected and recovered in the population. It tracks the average number of secondary infections and recoveries per tick. The reproduction number is calculated under different assumptions than those of the KM model, as we allow for more than one infected individual in the population, and introduce aforementioned variables.

At the end of the simulation, the R_0 reflects the estimate of the reproduction number, the final size relation that indicates whether there will be (or there was, in the model sense) an epidemic. This again closely follows the mathematical derivation that R_0 = beta*S(0)/ gamma = N*ln(S(0) / S(t)) / (N - S(t)), where N is the total population, S(0) is the initial number of susceptibles, and S(t) is the total number of susceptibles at time t. In this model, the R_0 estimate is the number of secondary infections that arise for an average infected individual over the course of the person's infected period.

## HOW TO USE IT

The SETUP button creates individuals according to the parameter values chosen by the user. Each individual has a 5% chance of being initialized as infected. Once the simulation has been setup, push the GO button to run the model. GO starts the simulation and runs it continuously until GO is pushed again.

Each time-step can be considered to be in hours, although any suitable time unit will do.

What follows is a summary of the sliders in the model.

INITIAL-PEOPLE (initialized to vary between 50 - 400): The total number of individuals the simulation begins with.
INFECTION-CHANCE (10 - 50): Probability of disease transmission from one individual to another.
RECOVERY-CHANCE (10 - 100): Probability of an individual's recovery once the infection has lasted longer than the person's recovery time.
AVERAGE-RECOVERY-TIME (50 - 300): Time it takes for an individual to recover, on average. The actual individual's recovery time is pulled from a normal distribution centered around the AVERAGE-RECOVERY-TIME at its mean, with a standard deviation of a quarter of the AVERAGE-RECOVERY-TIME. Each time-step can be considered to be in hours, although any suitable time unit will do.
AVERAGE-ISOLATION-TENDENCY (0 - 50): Average tendency of individuals to isolate themselves and will not spread the disease. Once an infected person is identified as an "isolator," the individual will isolate himself in the current location (as indicated by the grey patch) and will stay there until full recovery.
AVERAGE-HOSPITAL-GOING-TENDENCY (0 - 50): Average tendency of individuals to go to a hospital when sick. If an infected person is identified as a "hospital goer," then he or she will go to the hospital, and will recover in half the time of an average recovery period, due to better medication and rest.
INITIAL-AMBULANCE (0 - 4): Number of health officials or ambulances that move about at random, and force-quarantine sick individuals upon contact. The health officials are immune to the disease, and they themselves do not physically accompany the patient to the hospital. They move at a speed 5 times as fast as other individuals in the world and are not bounded by geographic region.
INOCULATION-CHANCE (0 - 50): Probability of an individual getting vaccinated, and hence immune from the virus.
INTRA-MOBILITY (0 - 1): This indicates how "mobile" an individual is. Usually, an individual at each time step moves by a distance 1. In this model, the person will move at a distance indicated by the INTRA-MOBILITY at each time-step. Thus, the lower the intra-mobility level, the less the movement in the individuals. Individuals move randomly by this assigned value; ambulances always move 5 times faster than this assigned value.

In addition, there are two switches, and a related slider:

LINKS? : When ON, there will be links randomly assigned between people, and the disease will spread twice as fast to those that the infected person is linked with as to the others. When OFF, the disease spreads with an equal chance to those around the infected person.
TRAVEL? : When ON, people from the two regions (separated by the yellow border in the middle) are allowed to migrate and mix. When OFF, the people stay in the region in which they live.
TRAVEL-TENDENCY (0 - 1): When TRAVEL? is ON, this slider indicates the probability of an individual to be traveling at each tick. The 1 indicates a 1 percent chance of travel per tick.

A number of graphs are also plotted in this model.

CUMULATIVE INFECTED AND RECOVERED: This plots the total percentage of individuals who have ever been infected or recovered.
POPULATIONS: This plots the number of people with or without the disease.
INFECTION AND RECOVERY RATES: This plots the estimated rates at which the disease is spreading. BetaN is the rate at which the cumulative infected changes, and Gamma rate at which the cumulative recovered changes.
R_0: This is an estimate of the reproduction number.

## THINGS TO NOTICE

As with many epidemiological models, the number of people becoming infected over time, in the event of an epidemic, traces out an "S-curve." It is called an S-curve because it is shaped like a sideways S. By changing the values of the parameters using the slider, try to see what kinds of changes make the S curve stretch or shrink.

Whenever there's a spread of the disease that reaches most of the population, we say that there was an epidemic. The reproduction number serves as an indicator for the likeliness of an epidemic to occur, if it is greater than 1. If it is smaller than 1, then it is likely that the disease spread will stop short, and we call this an endemic.

Notice how the introduction of various human behaviors, such as travel, inoculation, isolation and quarantine, help constrain the spread of the disease, and what changes that brings to the population level in terms of rate and time taken of disease spread, as well as the population affected.

## THINGS TO TRY

Compare this model with the epiDEM basic model. Do the added complexities significantly change the disease spread? What kinds of changes bring about interesting outcomes?

Notice the difference in dynamics when the travel chooser is on versus off. What happens to the population and the disease spread in both cases?

Does the disease spread change when the link chooser is on? What about when you increase the number of ambulances? What happens to the number of people infected?

Based on this model, what are some strategies or preventive measures that you think are important to undertake on the onset of a disease outbreak? Are there some that are more effective than others? Why might that be? What combinations work well? Are there some measures that seem redundant?

## EXTENDING THE MODEL

Are there other ways to change the behavior of the people once they are infected? Try to think about how you would introduce such a variable.

In this model, we introduce an option for travel, so that there is mixing between two otherwise closed populations. What happens when you introduce births and deaths to each region or just one?

What would happen when the virus mutates? How will that change the population dynamic and disease spread?

What would happen if the population had a mix of healthy and less healthy people, so as to have differing levels of susceptibility?

## NETLOGO FEATURES

Notice that each agent pulls from a truncated normal distribution, centered around the AVERAGE-RECOVERY-TIME set by the user, to determine its recovery-time. This is to account for the variation in genetic differences and the immune system functions of individuals. Similarly, an individual's isolation-tendency and hospital-going-tendency are pulled from truncated normal distributions centered around AVERAGE-ISOLATION-TENDENCY and AVERAGE-HOSPITAL-GOING-TENDENCY respectively.

Notice that R_0 calculated in this model is a numerical estimate to the analytic R_0. In the special case of one infective introduced to a wholly susceptible population (i.e., the Kermack-McKendrick assumptions), the numerical estimations of R_0 are very close to the analytic values. With added complexity in the models, such as the introduction of travel and control measures, the analytic R_0 becomes harder to derive. The numerical estimation is therefore a crude measure of what the actual R_0 might be.

In addition to travel and control measures, notice that this model introduces links amongst individuals and the individual's mobility, which also affect the dynamics of the disease transmission.

## RELATED MODELS

epiDEM basic, HIV, Virus and Virus on a Network are related models.

## HOW TO CITE

If you mention this model or the NetLogo software in a publication, we ask that you include the citations below.

For the model itself:

* Yang, C. and Wilensky, U. (2011).  NetLogo epiDEM Travel and Control model.  http://ccl.northwestern.edu/netlogo/models/epiDEMTravelandControl.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

Please cite the NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright 2011 Uri Wilensky.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact Uri Wilensky at uri@northwestern.edu.

<!-- 2011 Cite: Yang, C. -->
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

person lefty
false
0
Circle -7500403 true true 170 5 80
Polygon -7500403 true true 165 90 180 195 150 285 165 300 195 300 210 225 225 300 255 300 270 285 240 195 255 90
Rectangle -7500403 true true 187 79 232 94
Polygon -7500403 true true 255 90 300 150 285 180 225 105
Polygon -7500403 true true 165 90 120 150 135 180 195 105

person righty
false
0
Circle -7500403 true true 50 5 80
Polygon -7500403 true true 45 90 60 195 30 285 45 300 75 300 90 225 105 300 135 300 150 285 120 195 135 90
Rectangle -7500403 true true 67 79 112 94
Polygon -7500403 true true 135 90 180 150 165 180 105 105
Polygon -7500403 true true 45 90 0 150 15 180 75 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
