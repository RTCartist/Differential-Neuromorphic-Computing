% crop images and convert them to grayscale

clc;
clear all;
close all;

% Cropped size
sta_point_row = 1;
sta_point_col = 1;
fin_point_row = 900;
fin_point_col = 1920;

% the path where the original images are stored
folder_path = '..\datasets\Night\OriginalPic\'; 
% the path where the cropped greyscale images are stored
store_cut_path = '..\datasets\Night\CroppedPic\'; 

file_names =  dir(fullfile(folder_path,'*.jpg'));
for k = 1:length(file_names)
    pic_origin_cache = imread(fullfile(folder_path,file_names(k).name));
    pic_cut_cache = rgb2gray(pic_origin_cache);
    pic_cut_cache = pic_cut_cache(sta_point_row:fin_point_row,sta_point_col:fin_point_col,:);
    imwrite(pic_cut_cache,fullfile(store_cut_path,file_names(k).name));
end
