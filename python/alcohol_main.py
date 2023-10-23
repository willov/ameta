# %% Import packages
import matplotlib.pyplot as plt
import sund
import os
import numpy as np
import json
from contextlib import contextmanager
import copy

# %% Define useful functions
def close_to_square(n):
    b = np.round(np.sqrt(n))
    a = np.ceil(n/b)
    return int(a), int(b)

@contextmanager
def silent_errors(stdchannel, dest_filename):
    try:
        oldstdchannel = os.dup(stdchannel.fileno())
        dest_file = open(dest_filename, 'w')
        os.dup2(dest_file.fileno(), stdchannel.fileno())
        yield
    finally:
        if oldstdchannel is not None:
            os.dup2(oldstdchannel, stdchannel.fileno())
        if dest_file is not None:
            dest_file.close()

# %% Define the name of the model
model_name =  'alcohol_model'

# %% Setup model and model object and load parameter values
sund.installModel(f"./Models/{model_name}.txt")
Alcohol_model = sund.importModel(model_name)
model = Alcohol_model() 

fs = []
for path, subdirs, files in os.walk('./results'):
    for name in files:
        if model_name in name.split('(')[0] and "ignore" not in path:
            fs.append(os.path.join(path, name))
fs.sort()
with open(fs[0],'r') as f:
    param_in = json.load(f)
    params = param_in['x']

# %% Load and setup experimental data
with open('../data.json','r') as f:
    all_data = json.load(f)

for d in all_data.values():
    d.pop("meta",None)

validation_experiments = ["Okabe_Water2", "Okabe_Glucose", "Okabe_UG400", "Sarkola", "Javors_Low", "Frezza_Woman", "Frezza_Men"]

estimation_data = {k:d.copy() for k,d in all_data.items() if k not in validation_experiments}
estimation_data["Sarkola"] = all_data["Sarkola"].copy()
estimation_data["Sarkola"].pop("EtOH") #split the Sarkola data into estimation/validation group

estimation_data["Javors_Low"]= all_data["Javors_Low"].copy()
estimation_data["Javors_Low"]["PEth"]["SEM"] = np.inf # Disables using PEth data from Javors_Low in the cost calculations
estimation_data["Javors_Low"]["BrAC"]["SEM"] = np.inf # Disables using BrAC data from Javors_Low in the cost calculations

validation_data = {k:d.copy() for k,d in all_data.items() if k in validation_experiments}
validation_data["Sarkola"].pop("Acetate") #split the Sarkola data into estimation/validation group

print(estimation_data.keys())
print(validation_data.keys())
# %% Define simulation object creation helpers

def create_sim(model, t, vol, conc, t_drinks, kcal, kcal_food, sex, weight, height):
    pwc = sund.PIECEWISE_CONSTANT # space saving only
    const = sund.CONSTANT # space saving only

    act = sund.Activity(timeunit = 'm')
    act.AddOutput(name = "EtOH_conc", type=pwc, tvalues = t, fvalues = [0] + conc, feature = True) 
    vol_drink_per_t = [v/t if t>0 else 0 for v,t in zip(vol, t_drinks)]
    act.AddOutput(name = "vol_drink_per_time", type=pwc, tvalues = t, fvalues = [0] + vol_drink_per_t, feature = True) 
    act.AddOutput(name = "kcal_liquid_per_vol", type=const, fvalues = kcal, feature = True)
    act.AddOutput(name = "kcal_solid", type=const, fvalues = kcal_food, feature = True)
    act.AddOutput(name = "drink_length", type=pwc, tvalues = t, fvalues = [0] + t_drinks, feature = True)
    act.AddOutput(name = "sex", type=const, fvalues = sex, feature = True)
    act.AddOutput(name = "weight", type=const, fvalues = weight, feature = True)
    act.AddOutput(name = "height", type=const, fvalues = height, feature = True)

    sim = sund.Simulation(models = model, activities = act, timeunit = 'm')
    return sim


def create_sim_from_data(model, inputs, use_as_feature=True): 
    pwc = sund.PIECEWISE_CONSTANT # space saving only
    const = sund.CONSTANT # space saving only

    act = sund.Activity(timeunit = 'm')
    for key, inp in inputs.items():
        if len(inp["t"])>1:
            act.AddOutput(name = key, type=pwc, tvalues = np.array(inp["t"][1:]), fvalues = np.array(inp["f"]), feature = use_as_feature) 
        else:
            act.AddOutput(name = key, type=const, fvalues = np.array(inp["f"]), feature = True)

    sim = sund.Simulation(models = model, activities = act, timeunit = 'm')
    return sim

# %% Setup simulation object
sims = dict()

for k, v in all_data.items():
    if k == "Javors_Combined":
        continue
    else:
        sims[k] = create_sim_from_data(model, v["input"])

# %% Define a function to get the combined PEth

def combine_PEth(low, high):
    return  (np.array(low) * 16 + np.array(high) * 11) / (16 + 11)


# %% Define cost function
def f_cost(p, sims, D, print_costs = False):
    ic_PEth_L = p[-2]
    ic_PEth_H = p[-1]
    p = p[0:-2]
    p_names = model.parameternames
    ic = model.statevalues
    PEth_bound_scale = p[p_names.index("kPEth_bind")] / p[p_names.index("kPEth_release")] + 1

    cost = 0
    for k_exp, d in D.items():
        # Javors special cases
        if k_exp == "Javors_Combined":
            continue
        elif k_exp == "Javors_Low":
            ic[model.statenames.index("PEth")] = ic_PEth_L
            ic[model.statenames.index("PEth_Bound")] = ic_PEth_L*PEth_bound_scale
        elif  k_exp == "Javors_High":
            ic[model.statenames.index("PEth")] = ic_PEth_H
            ic[model.statenames.index("PEth_Bound")] = ic_PEth_H*PEth_bound_scale

        times = [t for k, var in d.items()  if k not in ["input", "meta", "extra"] for t in var["Time"]]+[0]

        if "Javors" in k_exp:
            times+=D["Javors_Combined"]["PEth"]["Time"]

        times = np.unique(np.array(times))
        
        sim = sims[k_exp]
        sim.ResetStatesDerivatives()        
        sim.Simulate(timevector = times, parametervalues = p,  statevalues = ic)

        for k_obs, obs in d.items():
            if k_obs not in ["input", "meta", "extra"]:
                idx = sim.featurenames.index(k_obs)
                y_sim = sim.featuredata[:,idx]

                if any([e in k_exp for e in ["Javors", "Okabe"]]): # If the experiment is either a Javors or an Okabe experiment, remove the basal value
                    if "Low" in k_exp:
                        PEth_L = y_sim.copy() 
                        PEth_t = sim.timevector
                    elif "High" in k_exp:
                        PEth_H = y_sim.copy()
                    y_sim-=y_sim[0]

                y_sim = [y for y,t in zip(y_sim, sim.timevector) if t in obs["Time"]] # only keep sim_times that is also in data. Useful if observables have different number of observables 
                y = np.array(obs['Mean'])
                sem = np.array(obs['SEM'])
                cost += np.square((y-y_sim)/sem).sum()

                if print_costs:
                    c = np.square((y-y_sim)/sem).sum()
                    print(f"{k_exp}-{k_obs}: {c}")

    if "Javors_Combined" in D.keys():
        obs = D["Javors_Combined"]["PEth"]
        y_sim = combine_PEth(PEth_L, PEth_H)
        y_sim = [y for y,t in zip(y_sim, PEth_t) if t in obs["Time"]] # only keep sim_times that is also in data. Useful if observables have different number of observables 
        y = np.array(obs['Mean'])
        sem = np.array(obs['SEM'])

        cost += np.square((y-y_sim)/sem).sum()
        if print_costs:
            c = np.square((y-y_sim)/sem).sum()
            print(f"Javors_Combined-{k_obs}: {c}")

    return cost

print(f"Cost for p_start: {f_cost(params, sims, estimation_data, print_costs=True)}")

# %% Simulate and plot agreement to data
def plot_agreement(p, sims, D):
    ic_PEth_L = p[-2]
    ic_PEth_H = p[-1]
    p = p[0:-2]
    p_names = model.parameternames
    ic_org = model.statevalues.copy()
    PEth_bound_scale = p[p_names.index("kPEth_bind")] / p[p_names.index("kPEth_release")] + 1


    plot_info = {k:{} for k in all_data.keys()}

    for key, observable, fig, position, title in zip(["Okabe_Water", "Okabe_Orange", "Okabe_Orange_Syrup", "Okabe_Milk_Water", "Okabe_Milk", "Okabe_Whiskey", "Okabe_UG200", "Okabe_UG600", "Mitchell_Beer", "Mitchell_Wine", "Mitchell_Spirit", "Jones_Fasting", "Kechagias_Fasting", "Javors_High", "Jones_Food", "Kechagias_Breakfast", "Sarkola", "Javors_High", "Javors_Combined", "Okabe_Water2", "Okabe_Glucose","Okabe_UG400", "Sarkola", "Javors_Low", "Javors_Low", "Frezza_Woman", "Frezza_Men"], 
                                                ["Gastric volume", "Gastric volume", "Gastric volume", "Gastric volume", "Gastric volume", "Gastric volume","Gastric volume", "Gastric volume", "EtOH", "EtOH", "EtOH", "EtOH", "EtOH", "BrAC", "EtOH", "EtOH", "Acetate", "PEth", "PEth", "Gastric volume", "Gastric volume", "Gastric volume", "EtOH", "BrAC", "PEth", "EtOH", "EtOH"],
                                                [1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4, 4],
                                                [1, 2, 3, 5, 6, 7, 8, 9, 1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 1, 2, 3, 4, 5, 6, 7, 8],
                                                ["Water", "Orange", "Orange_Syrup", "Milk_Water", "Milk", "Whiskey", "Uniform kcal 200ml", "Uniform kcal 600ml", "Beer BAC", "Wine BAC", "Spirit BAC", "Fasting BAC", "Fasting BAC", "High dose BrAC", "Food BAC", "Food BAC", "Acetate", "High dose PEth", "Long term PEth", "Water", "Glucose","Uniform kcal 400ml", "BAC", "Low dose BrAC", "Low dose PEth", "Woman Food BAC", "Men Food BAC"]):
        plot_info[key][observable] = {"fig": fig, "pos": position, "title":title}

    figs = [plt.figure(figsize=(19.2, 10.8)), plt.figure(figsize=(19.2, 10.8)), plt.figure(figsize=(19.2, 10.8)), plt.figure(figsize=(19.2, 10.8))]

    for k_exp, d in D.items():
        # Special cases for Javors PEth
        if k_exp == "Javors_Combined":
            continue
        elif k_exp == "Javors_Low":
            ic[model.statenames.index("PEth")] = ic_PEth_L
            ic[model.statenames.index("PEth_Bound")] = ic_PEth_L*PEth_bound_scale
        elif  k_exp == "Javors_High":
            ic[model.statenames.index("PEth")] = ic_PEth_H
            ic[model.statenames.index("PEth_Bound")] = ic_PEth_H*PEth_bound_scale
        else:
            ic = ic_org

        times = sorted([t for k, var in d.items()  if k not in ["input", "meta", "extra"] for t in var["Time"]])
        t_highres = np.arange(0, times[-1], 0.01)

        sim = sims[k_exp]
        sim.ResetStatesDerivatives()
        sim.Simulate(timevector = t_highres, parametervalues = p,  statevalues = ic)

        for k_obs, obs in d.items():
            if k_obs not in ["input", "meta", "extra"]:

                fignum = plot_info[k_exp][k_obs]["fig"]
                if fignum == 3: 
                    m,n = 2,2
                else:
                    m,n = 3,3
                fig = figs[fignum-1]
                ax = fig.add_subplot(m,n,plot_info[k_exp][k_obs]["pos"])

                idx = sim.featurenames.index(k_obs)
                y_sim = sim.featuredata[:,idx]
                if "Javors" in k_exp:
                    y_sim-=y_sim[0]
                ax.plot(sim.timevector, y_sim)
                ax.errorbar(obs['Time'], obs['Mean'], obs['SEM'], marker='o', capsize=5, linestyle='')
                ax.set_xlabel(f"Time ({sim.timeunit})")
                ax.set_title(plot_info[k_exp][k_obs]["title"])
                if "Unit" in obs.keys():
                    ax.set_ylabel(obs["Unit"])

    if "Javors_Combined" in D.keys():

        obs = D["Javors_Combined"]["PEth"]
        t_short_term = max(D["Javors_Low"]["PEth"]["Time"])
        t1 = np.arange(0, t_short_term, 0.01)
        t2 = np.arange(t_short_term, max(obs["Time"]), 1)

        ic_L = ic_org.copy()
        ic_H =ic_org.copy()
        ic_L[model.statenames.index("PEth")] = ic_PEth_L
        ic_L[model.statenames.index("PEth_Bound")] = ic_PEth_L*PEth_bound_scale
        ic_H[model.statenames.index("PEth")] = ic_PEth_H
        ic_H[model.statenames.index("PEth_Bound")] = ic_PEth_H*PEth_bound_scale

        sim_low = sims["Javors_Low"]
        sim_low.Simulate(timevector = t1, parametervalues = p,  statevalues = ic_L)
        sim_low_short = copy.copy(sim_low)
        sim_low.Simulate(timevector = t2, parametervalues = p)

        sim_high = sims["Javors_High"]
        sim_high.Simulate(timevector = t1, parametervalues = p,  statevalues = ic_H)
        sim_high_short = copy.copy(sim_high)
        sim_high.Simulate(timevector = t2, parametervalues = p)
        idx_PEth = sim_low.featurenames.index("PEth")

        PEth_L_short = sim_low_short.featuredata[:, idx_PEth]
        PEth_H_short = sim_high_short.featuredata[:, idx_PEth]
        PEth_L_long = sim_low.featuredata[:, idx_PEth]
        PEth_H_long = sim_high.featuredata[:, idx_PEth]

        obs = D["Javors_Combined"]["PEth"]
        y_sim_short = combine_PEth(PEth_L_short, PEth_H_short)
        y_sim_long = combine_PEth(PEth_L_long, PEth_H_long)

        idx_short_t = obs["Time"].index(t_short_term)+1
        
        fignum = plot_info["Javors_Combined"]["PEth"]["fig"]
        fig = figs[fignum-1]
        ax = fig.add_subplot(2,2,plot_info["Javors_Combined"]["PEth"]["pos"])
        ax.plot(sim_low_short.timevector, y_sim_short)
        ax.errorbar(obs['Time'][:idx_short_t], obs['Mean'][:idx_short_t], obs['SEM'][idx_short_t], marker='o', capsize=5, linestyle='')
        ax.set_xlabel(f"Time ({sim_low.timeunit})")
        ax.set_title(plot_info["Javors_Combined"]["PEth"]["title"])
        if "Unit" in obs.keys():
            ax.set_ylabel(obs["Unit"])

        ax = fig.add_subplot(2,2,plot_info["Javors_Combined"]["PEth"]["pos"]+1)
        ax.plot(sim_low.timevector[100:]/(60*24), y_sim_long[100:])
        ax.errorbar(np.array(obs['Time'][idx_short_t:])/(60*24), obs['Mean'][idx_short_t:], obs['SEM'][idx_short_t:], marker='o', capsize=5, linestyle='')
        ax.set_xlabel(f"Time (days)")
        ax.set_title(plot_info["Javors_Combined"]["PEth"]["title"])
        if "Unit" in obs.keys():
            ax.set_ylabel(obs["Unit"])

    fignames = ["estimation Gastric", "estimation EtOH", "estimation EtOH derivates", "validation"]
    for i in range(4):
        fig = figs[i]
        fig.tight_layout()
        fig.savefig(f"./figures/{fignames[i]}.png")


# %% Plot agreement figures
plot_agreement(params, sims, all_data)

plt.show()
plt.close('all')
