# A Physiological-Twin for Alcohol Consumption -- Connecting short-term drinking habits to plasma PEth

This project describe the appearance of alcohol in blood [mg/dL], breakdown to acetaldehyde, and conversion to phosphatidylethanol (PEth). 

## The model

The model files used to generate the results are available in `Matlab/Models`, with the primary model being `Matlab/Models/Alcoholmodel.txt` ([available here](https://github.com/willov/ameta/blob/notebook/Matlab/Models/AlcoholModel.txt)). These files contain the model equations in a plain text format.

## Different implementations

We implemented the model in two different frameworks to make it more accessible. The primary work was done in MATLAB using [IQM tools by IntiQuan](https://iqmtools.intiquan.com/), but we also provide a Python implementation in a custom toolbox.

### MATLAB

The MATLAB implementation is using IQM tools, which is a package that interfaces to the SUNDIALS suite of solvers. 

**To run the scripts which generate the plots in the paper, run `Matlab/alcoholModel.m`.** Note that you need to have MATLAB installed with a working C-compiler.

To plot the supplementary figures, run `MATLAB/plotSupplementaryFigures.m`.

For transparency, we also include the scripts used to run the parameter optimization. These can be run by passing extra arguments to `alcoholModel`: `alcoholModel(estimateOnAllData, doOptimize, doPI, doMCMC, doPPL)`. 

The additional scripts and functions used to run the simulations are available in the `Matlab/scripts` folder.

### Python

The Python implementation was implemented using a custom toolbox inspired by the IQM tools. The SUND (SimUlation of Nonlinear Dynamic models) toolbox is still in development, but an initial version is available [here](https://isbgroup.eu/edu/assets/sund-1.0.3.1.tar.gz). To install all packages needed, the simplest way is to install the packages defined in the `python/requirements.txt` file using `pip install -r requirements.txt`. Typically, you want to create a new virtual environment before installing the packages, e.g. using `pipenv shell`. We ran the Python scripts using Python 3.12.

The SUND toolbox is built around a modular object-oriented approach, where models have outputs and inputs, which can come from other models or what we call "activities". In this project, the activities correspond to the drinks and meals.

Please note that we did not include simulations of the rejected alternative hypothesis in the python example, only the accepted model.

To run the Python version, either run the script in `python/alcohol_main.py` or the notebook `python/alcohol_main.ipynb`. We also put a version of the notebook at [Google Colab, which can be used to run the notebook in the cloud](https://colab.research.google.com/drive/1v6OodokUK1YgXspWR77UHzs-YiqKjr07?usp=sharing).

## Streamlit alcohol app

The Python version of the model was used in a Streamlit application, to make it more available. [The application is available here.](https://alcohol.streamlit.app/) The code for running the application as it was at the time of the submission/publication is available at [GitHub here](https://github.com/willov/alcohol_app) with a permanent copy is available at Zenodo ([DOI: 10.5281/zenodo.10054300](https://doi.org/10.5281/zenodo.10054300)).

## The structure of the experimental data

All of the data used in the work is collected in the `data.json` file. Each entry in the JSON file corresponds to a single experiment (where we define a single experiments as giving a set of input and then measuring the outcome). This means that many experiments in our sense could come from the same original publication. For all entries in the JSON file, we have defined the inputs to our model, the measured data, and some additional meta information such as the DOI, and drink information. 

For the inputs, we define the value of the input at `t` to the corresponding value of `f`. We use `t = -Infinity` to highlight what the value of an input would be before any stimulation starts.  

All information not in the `meta` or `input` field, will be interpreted as an observable (such as ethanol concentration in the blood). An observable will contain `Time`, `Mean` and `SEM` fields with the corresponding values. If available, it could also contain individual measurement points in the `Points` field. An observable can also contain additional information, such as `ylim` for setting the limit of the y-axis when plotting the observable.

An entry can look like this: 

```JSON
"Mitchell_Beer": {
    "meta": {
      "doi": "10.1111/acer.12355",
      "conc": 5.1,
      "volume": 1.027,
      "time": 20,
      "kcal": 389.0
    },
    "input": {
      "EtOH_conc": { "t": [-Infinity], "f": [5.1] },
      "vol_drink_per_time": {
        "t": [-Infinity, 0, 20],
        "f": [0, 0.05134999999999999, 0]
      },
      "kcal_liquid_per_vol": {
        "t": [-Infinity],
        "f": [129.82]
      },
      "kcal_solid": { "t": [-Infinity], "f": [0] },
      "sex": { "t": [-Infinity], "f": [1] },
      "weight": { "t": [-Infinity], "f": [82.66] },
      "height": { "t": [-Infinity], "f": [1.7711583490849163] }
    },
    "EtOH": {
      "Mean": [
        19.40065997, 34.59520339, 47.03908762, 45.56389434, 44.45473635,
        42.79560442, 37.09797957, 31.58297765, 25.51879122, 20.00405244,
        17.60258725
      ],
      "SEM": [
        7.875679573, 13.00359457, 11.17236552, 10.80606708, 6.04366109,
        6.960196622, 4.945292065, 4.395581262, 4.578730481, 4.944765774,
        4.395581262
      ],
      "Time": [
        19.748854001652564, 30.03962970175097, 44.73261792862444,
        60.1758864053808, 75.27527643427419, 90.7526485587525,
        119.78053671141895, 151.16441852754346, 180.5958665115863,
        210.43371629764914, 241.05168702535147
      ],
      "Unit": "mg/dL", 
      "ylim": [0, 100],
      "xlim": [0, 250]
    }
}
```
