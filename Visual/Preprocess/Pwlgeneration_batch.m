% creat the pwl files for subsequent simulation

% the compressed parameters
m = 36;
n = 48;
mem_row_length = 900/m;
mem_col_length = 1920/n;

% set the read path for compressed matrixs and define the storage path for PWL files
read_path = '..\datasets\Night\CompressedMatrix\';
read_file_list = dir(fullfile(read_path,'*.txt'));
pwl_store_path = '..\pwl\scene1\';
% scale rate  serves as the multiplier for transforming image grayscale intensities into voltage amplitudes
% time_delta represents the time interval in the generated PWL file; please do not alter 
scale_rate = 0.01;
time_delta = 0.1;
% sta is the starting index for reading the matrix
sta = 1;

for i = 1:mem_row_length
    for j = 1:mem_col_length
        file_pwlpath = fullfile(pwl_store_path,strcat(num2str(i),'_',num2str(j),'.txt'));
        filepwlID = fopen(file_pwlpath,'w');
        for k = 1:length(read_file_list)
            matrix_read_name = fullfile(read_path,strcat('mat_',num2str(k-1+sta),'.jpg.txt'));
            matrix_cache = readmatrix(matrix_read_name);
            % if k == 1
            %     A0 = [0,scale_rate*matrix_cache(i,j)];
            %     fprintf(filepwlID,'%f,%f\n',A0);
            % end
            % A1 = [(k-1)+time_delta,scale_rate*matrix_cache(i,j)];
            % A2 = [k,scale_rate*matrix_cache(i,j)];
            % fprintf(filepwlID,'%f,%f\n',A1);
            % fprintf(filepwlID,'%f,%f\n',A2);
            if k == 1
                A0 = [0,scale_rate*matrix_cache(i,j)];
                fprintf(filepwlID,'%f,%f\n',A0);
            else
            A1 = [(k-2)+time_delta,scale_rate*matrix_cache(i,j)];
            A2 = [k-1,scale_rate*matrix_cache(i,j)];
            fprintf(filepwlID,'%f,%f\n',A1);
            fprintf(filepwlID,'%f,%f\n',A2);
            end
        end
        fclose(filepwlID);
    end
end
