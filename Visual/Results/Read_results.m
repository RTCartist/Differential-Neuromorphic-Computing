clear
clc
% the path where the results of the SPICE simulations are stored 
raw_path = '..\Simulation\out\';
% adjust the parameters to fit the specific configurations
total_time = 460;
mem_row = 45;
mem_col = 96;

% store the memristor states
mem_state = zeros (mem_row, mem_col, total_time+1);
store_mat_path = '.\1.mat';
time_found = zeros(total_time,1);

single_count = 0;
total_count = 0;

lost_found = [];

for i=1:mem_row %row
    for j=1:mem_col %col

        raw_name = strcat(num2str(i),'_',num2str(j));
        raw_full_name = fullfile(raw_path,raw_name);
        raw_data = LTspice2Matlab(raw_full_name);
        if(strcmp(raw_data.variable_name_list(12),'V(v1_mr)')==1)
            loc = 12;
        else
            for k = 1:length(raw_data.variable_name_list)
                if(strcmp(raw_data.variable_name_list(k),'V(v1_mr)')==1)
                    fprintf('%d\n',k);
                    loc = k;
                break;
                end
            end
        end
        mem_matrix_cache = raw_data.variable_mat;
        mem_state(i,j,1) = 0.5;
        time_found(1,1) = 1;
        for time_loc = 1:length(raw_data.time_vect)
            for t = 1:1:total_time-1
                if (raw_data.time_vect(time_loc)==t)
                    mem_state(i,j,t+1) = mem_matrix_cache(loc, time_loc);
                    time_found(t+1,1) = 1;
                end
            end
        end
        clear mem_matrix_cache
        fprintf('%d %d\n',i,j);
        if (all(time_found))
            total_count = total_count+1;
        end
    end
end
save(store_mat_path,'mem_state','time_found','single_count',"total_count");