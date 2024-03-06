% compress these images

% the compressed parameters
m = 36;
n = 48;

%set the read path for cropped images and define the storage path for both the compressed images and their corresponding matrixs
folder_path = '..\datasets\Night\CroppedPic\';
store_img_path = '..\datasets\Night\CompressedPic\';
store_matrix_path = '..\datasets\Night\CompressedMatrix\';
file_names = dir(fullfile(folder_path,'*.jpg'));
for k = 1:length(file_names)

    img = imread(fullfile(folder_path,file_names(k).name));
    
    % get the number of rows and columns of the image
    [rows, cols] = size(img);
    % calculate the number of rows and columns in each block to be compressed
    block_rows = floor(rows / m);
    block_cols = floor(cols / n);
    
    % create an empty matrix to store the reconstructed image
    reconstructed_img = zeros(block_rows, block_cols);
    
    % loop through each block
    for i = 1:block_rows
        for j = 1:block_cols
            % calculate the position of the top-left and bottom-right pixels of the current block
            block_start_row = (i - 1) * m+ 1;
            block_end_row = i * m;
            block_start_col = (j - 1) * n + 1;
            block_end_col = j * n;
    
            % extract the current block from the original image
            block = img(block_start_row:block_end_row, block_start_col:block_end_col);
    
            % calculate the average grayscale value of the current block
            block_mean = round(mean(block(:)));
    
            % set the grayscale value for the current block in the reconstructed image
            reconstructed_img(i, j) = block_mean;
        end
    end
    new_img_name = fullfile(store_img_path,['img_',file_names(k).name]);
    % display the reconstructed image
    imshow(reconstructed_img, [0 255]);
    new_matrix_name = fullfile(store_matrix_path,['mat_',file_names(k).name,'.txt']);
    writematrix(reconstructed_img,new_matrix_name);
    % min_val = min(reconstructed_img(:));
    % max_val = max(reconstructed_img(:));
    reconstructed_img = (reconstructed_img - 0) / (255 - 0);
    % reconstructed_img = imadjust(reconstructed_img, [0 255], [0 1]);
    imwrite(reconstructed_img, new_img_name);
end