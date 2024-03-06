For the visual processing, all the necessary codes and resources are provided, including:
1. Datasets: Speperated frames from the car recorder, captured under various scenarios.
2. Preprocess Steps: Detailed codes on how to convert images into analog voltage profiles (PWL).
3. Circuit: SPICE circuit and models used for simulations.
4. Simulation: Specific code utilized for processing visual information through the memristor array.
5. Results Readout: Codes about reading the memristor array state after simulations.

Required software and version:
1. LTspiceXVII
2. Python 3.9
3. MATLAB R2023a

Dependencies:
Python (PyLTspice)

Configuration instruction:
1. Download the binary file for LTspice XVII from http://ltspice.analog.com and execute the installation program. It is recommended to install the software in the directory 'C:\Program Files\LTC\LTspiceXVII' to facilitate ease of access for subsequent simulations.
2. Add the SPICE_models to the Library Search Path in LTspice XVII manually. (Detailed instructions can be found in https://uspas.fnal.gov/materials/17NIU/LTspiceXVII%20Installation.pdf.) Notice: in the first use, please modify the .lib instructions in the 'visual627.asc' within the 'Simulation' folder to guarantee successful simulation in LTspice.
Subsequently, remove any instructions related to simulation time, such as 'tran 0 900 0 0.01'.
3. Install PyLTspice using the prompt 'pip install PyLTSpice'.

The code using steps:
1. Image Conversion: Convert images into analog voltage profiles (PWL voltages in simulation) using the codes within the 'Preprocess' folder. Start with CropPic.m to crop images and convert them to grayscale. Next, apply PicCompression.m to compress these images. Finally, use Pwlgeneration_batch.m to create the PWL files.
2. Simulation Execution: Proceed by running the LTspice_simulation.py script found in the 'Simulation' folder.
3. Results Extraction: Use the Read_results.m script from the 'Results' folder to extract the simulation outcomes. This process will yield a .mat file containing the states of the memristor array.

Notice:
Due to the substantial size of the datasets, they have been uploaded to a Google Drive link: https://drive.google.com/drive/folders/1NVT2QtQ8jdO_O6yDDG2dBwHM4RsZ_nUo?usp=sharing.