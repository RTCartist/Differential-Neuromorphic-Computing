# equivalent simulation
import numpy as np
import matplotlib.pyplot as plt
from scipy import signal
import random
import time

# the corresponding parameters of VTEAM memristor model are：alpha_off, alpha_on, v_off, v_on, R_off, R_on, k_off, k_on, k_for(0), w_off, w_on, w_ini
# more information about the VTEAM model can be found in https://ieeexplore.ieee.org/abstract/document/7110565/ 
Knowm = [1.2, 3, 0.18, -0.12, 150e3, 30e3, 134, -18, 0, 1, 0, 1, "linear"]
Knowm_exp = [1.2, 3, 0.18, -0.12, 200e3, 20e3, 134, -18, 0, 1, 0, 0.5, "exp"]
Knowm_real = [1.2, 3, 0.18, -0.12, 150e3, 30e3, 134, -18, 0, 1, 0, 1, "real"]

# window function
def F(x, w_off, w_on):
    if w_on <= x <= w_off:
        return 1
    else:
        return 0
def window_weight(x, w_off, w_on):
    if w_on <= x <= w_off:
        return x
    elif x < w_on:
        return w_on
    else:
        return w_off
# define a class for describing the memristor model
class MemristorModel:
    def __init__(self, R_off, R_on, alpha_off, alpha_on, v_off, v_on, k_off, k_on, k_for, w_off, w_on, w_ini, R_w_type):
        self.R_off = R_off
        self.R_on = R_on
        self.alpha_off = alpha_off
        self.alpha_on = alpha_on
        self.v_off = v_off
        self.v_on = v_on
        self.k_off = k_off
        self.k_on = k_on
        self.k_for = k_for
        self.w_off = w_off
        self.w_on = w_on
        self.w_ini = w_ini
        self.state = w_ini
        self.R_w_type = R_w_type
        # characters
        self.x_ini = (w_ini - w_on) / (w_off - w_on)
        self.lambda_val = np.log(R_off / R_on)
        #  resistance state--stored discretely with a time interval of dt, covering every time point
        self.R_history = [(self.R_on / np.exp(-self.lambda_val*(self.state-self.w_on)/(self.w_off-self.w_on))) if (self.R_w_type == "exp") else (self.R_on + (self.R_off - self.R_on) / (self.w_off - self.w_on) * self.state)]

    def update_state(self, V, dt):  #check if the weight updates are too large, and verify if the parameter range is normal
        if V > self.v_off:
            g_delta = self.k_off * ((V / self.v_off - 1) ** self.alpha_off) * F(self.state, self.w_off, self.w_on)
        elif V < self.v_on:
            g_delta = self.k_on * ((V / self.v_on - 1) ** self.alpha_on) * F(self.state, self.w_off, self.w_on)
        else:
            #g_delta = self.k_for * 1e-9 * self.norm
            g_delta = 0

        if self.R_w_type == "real":
            if self.state < 0.1:
                g_delta /= 100
            elif 0.1 < self.state < 0.25:
                g_delta /= 4
            elif 0.25 < self.state < 0.3:
                g_delta /= 100
            elif 0.3 < self.state < 0.45:
                g_delta /= 4
            elif 0.45 < self.state < 0.5:
                g_delta /= 100
            elif 0.5 < self.state < 0.75:
                g_delta /= 4
            elif 0.75 < self.state < 0.8:
                g_delta /= 100
            elif 0.8 < self.state < 0.85:
                g_delta /= 100
            elif 0.85 < self.state < 0.99:
                g_delta /= 4
            else:
                g_delta /= 100
            g_delta *= 0.7+0.3*random.random()

        self.state -= g_delta * dt
        self.state = window_weight(self.state, self.w_off, self.w_on)

    def resistance(self):  # solve current resistance state
        state = self.state + 0.01 * random.random()
        if self.R_w_type == "exp":
            r = self.R_on / np.exp(-self.lambda_val*(state-self.w_on)/(self.w_off-self.w_on))
        elif self.R_w_type == "real":
            r = self.R_on + (self.R_off - self.R_on) / (self.w_off - self.w_on) * state
        else:  # linear
            r = self.R_on + (self.R_off - self.R_on) / (self.w_off - self.w_on) * state
        return r

    def simulate(self, input_voltage, time_start=-1.0, dt=0.0001):
        history = []
        for t in range(len(input_voltage)):
            V = input_voltage[t]
            self.update_state(V, dt)
            # history.append(self.resistance())
        if time_start != -1:
            last_element = self.R_history[-1]
            while len(self.R_history)*dt < time_start:
                self.R_history.append(last_element)
            self.R_history.append(self.resistance())
        return history

    def simulate_series_connection(self, input_voltage, time_start=-1.0, dt=0.00001, R0=20e3):
        history = []
        for t in range(len(input_voltage)):
            V = input_voltage[t]*self.resistance()/(R0+self.resistance())
            self.update_state(V, dt)
            history.append(self.resistance())
        if time_start != -1:
            last_element = self.R_history[-1]
            while len(self.R_history)*dt < time_start:
                self.R_history.append(last_element)
            self.R_history += history
        # print("time_start:", time_start)
        return history

def Create_Memristor_Model(Memristor_Type):
    alpha_off = Memristor_Type[0]
    alpha_on = Memristor_Type[1]
    v_off = Memristor_Type[2]
    v_on = Memristor_Type[3]
    R_off = Memristor_Type[4]
    R_on = Memristor_Type[5]
    k_off = Memristor_Type[6]
    k_on = Memristor_Type[7]
    k_for = Memristor_Type[8]
    w_off = Memristor_Type[9]
    w_on = Memristor_Type[10]
    w_ini = Memristor_Type[11]
    R_w_type = Memristor_Type[12]
    memristor = MemristorModel(R_off, R_on, alpha_off, alpha_on, v_off, v_on, k_off, k_on, k_for, w_off, w_on, w_ini, R_w_type)
    return memristor

# functions used for generating voltage pulses
def pulse_generate(total_len, pulse_len, pulse_Amplitude, dt):
    waveform = np.zeros(int(total_len / dt))  # initial as zero
    waveform[0:int(pulse_len / dt)] = pulse_Amplitude  # set to 1 during the pulse period
    return waveform

def input_generate(frequency, Amplitude, input_voltage_type, time_len, dt):
    t = np.arange(0, time_len, dt)
    if input_voltage_type == "triangle":
        input_voltage = Amplitude * signal.sawtooth(2 * np.pi * frequency * t, width=0.5)
    elif input_voltage_type == "sin":
        input_voltage = Amplitude * np.sin(2 * np.pi * frequency * t)
    else:
        input_voltage = Amplitude * np.sin(2 * np.pi * frequency * t)
    return input_voltage

def generate_pulse_signal(amp, duty, time_len, dt):
    """
    Generate a pulse signal.

    Parameters:

    amp: The amplitude of the pulse.
    duty: The duty cycle of the pulse, defined as the proportion of the high level duration to the total period.
    time_len: The total time length of the signal.
    dt: The time step, determining the sampling rate of the signal.
    Returns:

    t: Time array.
    pulse_signal: The generated pulse signal array.

    """
    t = np.arange(0, time_len, dt)  # creat time array
    frequency = 1 / time_len  # define the frequency to match the entire time length as one period

    # generate a square wave pulse signal, with the duty cycle controlled by the 'duty' parameter
    #pulse_signal = amp * signal.square(2 * np.pi * frequency * t, duty)
    pulse_signal = amp * (signal.square(2 * np.pi * frequency * t, duty) > 0).astype(float)
    return t, pulse_signal

# modulation scheme parameters
def modulation_selection(sen, mem):
    if sen <= 2:         
        if mem < 0.2:
            amp = -0.2
            duty = 0.5
        elif mem < 0.4:
            amp = -0.3
            duty = 0.3
        elif mem > 0.8:
            amp = 0.25
            duty = 0.5
        elif mem > 0.6:
            amp = 0.3
            duty = 0.2
        else: 
            amp = 0
            duty = 0       
    elif sen > 2 and sen < 6:
        amp = -0.3
        duty = 0.3
    elif sen >= 6:
        if mem < 0.3:
            amp = 0.4
            duty = 0.3
        else:
            amp = 0.3
            duty = 0.2
    return amp, duty

if __name__ == "__main__":
    # -----Design simulation sampling interval and total time-----

    sample_rate = 100000
    dt = 0.00001
    time_len = 0.001
    p = np.random.randint(1, 11, size=10)
    print(p)
    # -----Model selection-----
    Memristor_Type = Knowm_exp

    # -----Create Memristor Model-----
    memristor = Create_Memristor_Model(Memristor_Type)

    # -----Simulate-----
    # R the initial resistance of the memristor
    R = 100e3

    start_time = time.time()
    for i in range(len(p)):
        R_norm = (R-20e3)/180e3
        print(p[i], R_norm)
        amp1, duty1 = modulation_selection(p[i], R_norm)
        pulse_t, pulse = generate_pulse_signal(amp1, duty1, time_len, dt)
        print(pulse)
        resistance_history = memristor.simulate_series_connection(pulse, R0=0, time_start=-1.0, dt=0.00001)
        #print(resistance_history)
        R = resistance_history [-1]

    #print(resistance_history)

    end_time = time.time()
    total_time = end_time - start_time
    print(f"The processing time：{total_time} seconds")

