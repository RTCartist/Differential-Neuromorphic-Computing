from PyLTSpice import SimRunner, SpiceEditor
# choose the PWL and output paths
origin_path = '../Preprocess/pwl/scene1/'
runner = SimRunner(output_folder='./out')
# adjust the row length, col length and the end time of simulation
row_len = 46
col_len = 97
end_time = 460
for row_i in range(1, row_len):
    for col_j in range(1, col_len):
        netlist = SpiceEditor("visual627.asc")
        instruction = ".tran 0 {} 0 0.01".format(end_time)
        netlist.add_instructions(instruction)
        value_settings = {'vup': 0.16, 'vun': 0.01, 'bia1': 0.12, 'plus1': 1, 'bia2': 0.14, 'plus2': 1, 'bia0': -0.10}
        netlist.set_parameters(**value_settings)
        pwl_file_name = '{}_{}.txt'.format(row_i, col_j)
        netlist.set_component_value('V1', 'PWL file=' + origin_path + pwl_file_name)
        run_netlist_file = "{}_{}.net".format(row_i, col_j)
        raw, log = runner.run_now(netlist, run_filename=run_netlist_file)
