### Pipeline de Subsídio

```
Guilherme Braga (SUBP) - 01/06/2023
GTFS:

Houve uma demanda das coordenadorias regionais para manter os itinerários regulares no GTFS. Em virtude disso, algumas mudanças foram feitas no feed.

Tanto trips com os calendários regulares e as trips com eventuais desvios estão no GTFS. Quando há desvio, há desativação da trip regular através do calendar_dates. Mantivemos o padrão do GTFS para estes casos.
```

Dessa forma, os `service_id` ficaram assim definidos:
    - `U_REG`: Shapes regulares em dia útil
    - `U_OBRA_XXX`: Shapes de desvios de obras em dia útil
    - `D_DESAT_OBRA_XXX`: Shapes de regulares desativados em virtude de obras em dia útil
    - `S_REG`: Shapes regulares aos sábados
    - `S_OBRA_XXX`: Shapes de desvios de obras aos sábados
    - `S_DESAT_OBRA_XXX`: Shapes de regulares desativados em virtude de obras aos sábados
    - `D_REG`: Shapes regulares aos domingos
    - `D_OBRA_XXX`: Shapes de desvios de obras aos domingos
    - `D_DESAT_OBRA_XXX`: Shapes de regulares desativados em virtude de obras aos domingos