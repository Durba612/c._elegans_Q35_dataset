% clc; clear; close all;
% img_folder    = "C:\Users\durba\Downloads\Durba_PM\Durba_PM\Agg\";
% manual_folder = "D:\manual_gt";
% if ~exist(manual_folder,'dir'), mkdir(manual_folder); end
% 
% imds = imageDatastore(img_folder);
% oF   = imds.Files;
% selected = 1:10:numel(oF);
% all_areas_px  = [];
% all_areas_um2 = [];
% scaleBar_um   = 100;
% 
% % CSV to store all box coordinates
% csv_path = fullfile(manual_folder, 'manual_boxes.csv');
% fcsv = fopen(csv_path, 'w');
% fprintf(fcsv, 'img_idx,box_num,x,y,width,height,area_px,area_um2\n');
% 
% for idx = 1:length(selected)
%     j   = selected(idx);
%     img = imread(oF{j});
%     R = img(:,:,1);
%     G = img(:,:,2);
%     B = img(:,:,3);
% 
%     BW_sb  = R>200 & G>200 & B>200;
%     BW_sb  = bwareaopen(BW_sb,5);
%     CC_sb  = bwconncomp(BW_sb);
%     st_sb  = regionprops(CC_sb,'BoundingBox');
%     widths = zeros(1,CC_sb.NumObjects);
%     for k = 1:CC_sb.NumObjects
%         widths(k) = st_sb(k).BoundingBox(3);
%     end
%     [scaleBar_px,~] = max(widths);
%     um_per_pixel    = scaleBar_um / scaleBar_px;
% 
%     fprintf('\n[%d/%d] %.4f um/px — Draw boxes, CLOSE figure when done\n', idx, length(selected), um_per_pixel);
% 
%     fig = figure('Name', sprintf('img_%d — CLOSE when done', idx));
%     imshow(G,[]); hold on;
%     title(sprintf('img_%d | Draw aggregates | CLOSE when done', idx),'Color','w');
%     set(gcf,'Color','k');
% 
%     boxes = [];
%     while ishandle(fig)
%         try
%             pos = getrect(fig);
%             if ~ishandle(fig), break; end
%             if pos(3)<2 || pos(4)<2, continue; end
%             boxes(end+1,:)       = pos;
%             area_px              = pos(3)*pos(4);
%             area_um2             = area_px*um_per_pixel^2;
%             all_areas_px(end+1)  = area_px;
%             all_areas_um2(end+1) = area_um2;
%             rectangle('Position',pos,'EdgeColor','w','LineWidth',1.5);
%             fprintf('  Box %d: %.1f px² = %.2f um²\n', size(boxes,1), area_px, area_um2);
%             fprintf(fcsv, '%d,%d,%.2f,%.2f,%.2f,%.2f,%.2f,%.4f\n', ...
%                 idx, size(boxes,1), pos(1), pos(2), pos(3), pos(4), area_px, area_um2);
%         catch
%             break;
%         end
%     end
% 
%     fig2 = figure('Visible','off');
%     imshow(G,[]); hold on;
%     for k = 1:size(boxes,1)
%         rectangle('Position',boxes(k,:),'EdgeColor','w','LineWidth',1.5);
%     end
%     title(sprintf('img_%d | %d aggregates', idx, size(boxes,1)),'Color','w');
%     saveas(fig2, fullfile(manual_folder, sprintf('img_%d.png', idx)));
%     close(fig2);
%     fprintf('  Saved img_%d.png | %d boxes\n', idx, size(boxes,1));
% end
% 
% fclose(fcsv);
% 
% mean_area_px        = mean(all_areas_px);
% std_area_px         = std(all_areas_px);
% mean_area_um2       = mean(all_areas_um2);
% std_area_um2        = std(all_areas_um2);
% upper_threshold_px  = mean_area_px  + 2*std_area_px;
% upper_threshold_um2 = mean_area_um2 + 2*std_area_um2;
% 
% 
% 
% 
% 
% fprintf('\nMANUAL ANNOTATION SUMMARY');
% fprintf('Total boxes drawn:        %d\n',     length(all_areas_px));
% fprintf('Mean area:                %.2f px²  =  %.2f um²\n', mean_area_px,  mean_area_um2);
% fprintf('SD area:                  %.2f px²  =  %.2f um²\n', std_area_px,   std_area_um2);
% fprintf('Upper threshold (mean+2SD): %.2f px²  =  %.2f um²\n', upper_threshold_px, upper_threshold_um2);
% fprintf('Used in next code :       max_area_px = %.0f\n', upper_threshold_px);
% 
% 
% 
% %%


clc; clear; close all;

img_folder    = "C:\Users\durba\Downloads\Durba_PM\Durba_PM\Agg\";
manual_folder = "D:\manual_gt";
out_folder    = "D:\comparison_adaptive";
if ~exist(out_folder,'dir'), mkdir(out_folder); end

imds = imageDatastore(img_folder);
oF   = imds.Files;
selected = 1:10:numel(oF);

min_area_px    = 100;
max_area_px    = 2981;
iou_threshold      = 0.3;
centroid_threshold = 50;

csv_path = fullfile(manual_folder, 'manual_boxes.csv');
csv_data = readtable(csv_path);

% Three threshold methods to test
methods = {'Mean+2SD', 'Otsu', 'Percentile75'};

for method_idx = 1:3
    fprintf('\n');
    fprintf('METHOD %d: %s\n', method_idx, methods{method_idx});
    fprintf('\n');

    method_folder = fullfile(out_folder, methods{method_idx});
    if ~exist(method_folder,'dir'), mkdir(method_folder); end

    all_precision     = [];
    all_recall        = [];
    all_iou           = [];
    manual_counts_all = [];
    auto_counts_all   = [];
    mv_values         = [];  % track mv per image for reporting

    for idx = 1:length(selected)
        j   = selected(idx);
        img = imread(oF{j});
        R = img(:,:,1);
        G = img(:,:,2);
        B = img(:,:,3);

        % Scale bar detection
        BW_sb  = R>200 & G>200 & B>200;
        BW_sb  = bwareaopen(BW_sb,5);
        CC_sb  = bwconncomp(BW_sb);
        st_sb  = regionprops(CC_sb,'BoundingBox');
        widths = zeros(1,CC_sb.NumObjects);
        for k = 1:CC_sb.NumObjects
            widths(k) = st_sb(k).BoundingBox(3);
        end

        % Adaptive mv per image based on method
        G_flat = double(G(G > 30));  % ignore dark background

        if method_idx == 1
            % Method 1: Mean + 2 SD
            mv = mean(G_flat) + 2*std(G_flat);

        elseif method_idx == 2
            % Method 2: Otsu's threshold
            mv = graythresh(G) * 255;

        elseif method_idx == 3
            % Method 3: 75th percentile
            mv = prctile(G_flat, 75);
        end

        mv_values(end+1) = mv;
        fprintf('[%d/12] img_%d | Adaptive mv = %.1f\n', idx, idx, mv);

        % Auto detection with watershed
        BW = R < mv & G > mv & B < mv;
        BW = bwareaopen(BW, 50);

        % WATERSHED to split touching aggregates
        D  = -bwdist(~BW);
        D  = imhmin(D, 2);
        L  = watershed(D);
        BW = BW & (L > 0);

        CC    = bwconncomp(BW);
        stats = regionprops(CC, 'BoundingBox', 'Area');

        if isempty(stats)
            fprintf('  No detections for img_%d\n', idx);
            manual_counts_all(end+1) = 0;
            auto_counts_all(end+1)   = 0;
            continue;
        end

        keep  = [stats.Area] >= min_area_px & [stats.Area] <= max_area_px;
        stats  = stats(keep);
        numAgg = sum(keep);
        auto_boxes = zeros(numAgg, 4);
        for k = 1:numAgg
            auto_boxes(k,:) = stats(k).BoundingBox;
        end

        % Load manual boxes
        rows = csv_data(csv_data.img_idx == idx, :);
        if isempty(rows)
            fprintf('  No manual boxes for img_%d — skipping\n', idx);
            continue;
        end
        manual_boxes = [rows.x, rows.y, rows.width, rows.height];

        % Store counts
        manual_counts_all(end+1) = size(manual_boxes,1);
        auto_counts_all(end+1)   = numAgg;

        % Save three-panel figure
        fig3 = figure('Visible','off','Position',[0 0 1800 600]);

        subplot(1,3,1);
        imshow(G,[]);
        title(sprintf('img\\_idx %d | Original', idx),'Color','w');
        set(gca,'Color','k');

        subplot(1,3,2);
        imshow(G,[]); hold on;
        for k = 1:size(manual_boxes,1)
            rectangle('Position',manual_boxes(k,:),'EdgeColor','y','LineWidth',1.5);
        end
        title(sprintf('img\\_idx %d | Manual: %d', idx, size(manual_boxes,1)),'Color','w');
        set(gca,'Color','k');

        subplot(1,3,3);
        imshow(G,[]); hold on;
        for k = 1:numAgg
            rectangle('Position',auto_boxes(k,:),'EdgeColor','r','LineWidth',1.5);
        end
        title(sprintf('img\\_idx %d | Auto: %d | mv=%.1f', idx, numAgg, mv),'Color','w');
        set(gca,'Color','k');

        set(fig3,'Color','k');
        saveas(fig3, fullfile(method_folder, sprintf('img_%d_comparison.png', idx)));
        close(fig3);

        if isempty(manual_boxes) || numAgg == 0
            fprintf('  Skipping metrics for img_%d\n', idx);
            continue;
        end

        % Centroids
        auto_centroids = zeros(numAgg,2);
        for a = 1:numAgg
            auto_centroids(a,:) = [auto_boxes(a,1)+auto_boxes(a,3)/2, ...
                                   auto_boxes(a,2)+auto_boxes(a,4)/2];
        end
        man_centroids = zeros(size(manual_boxes,1),2);
        for m = 1:size(manual_boxes,1)
            man_centroids(m,:) = [manual_boxes(m,1)+manual_boxes(m,3)/2, ...
                                  manual_boxes(m,2)+manual_boxes(m,4)/2];
        end

        % IoU + centroid matching
        matched_auto = false(numAgg,1);
        matched_man  = false(size(manual_boxes,1),1);

        for m = 1:size(manual_boxes,1)
            best_score = -1;
            best_a     = -1;
            for a = 1:numAgg
                if matched_auto(a), continue; end
                ix1   = max(manual_boxes(m,1), auto_boxes(a,1));
                iy1   = max(manual_boxes(m,2), auto_boxes(a,2));
                ix2   = min(manual_boxes(m,1)+manual_boxes(m,3), auto_boxes(a,1)+auto_boxes(a,3));
                iy2   = min(manual_boxes(m,2)+manual_boxes(m,4), auto_boxes(a,2)+auto_boxes(a,4));
                inter = max(0,ix2-ix1)*max(0,iy2-iy1);
                area_m = manual_boxes(m,3)*manual_boxes(m,4);
                area_a = auto_boxes(a,3)*auto_boxes(a,4);
                uni    = area_m+area_a-inter;
                iou    = inter/uni;
                dist   = sqrt(sum((man_centroids(m,:)-auto_centroids(a,:)).^2));
                if iou >= iou_threshold || dist <= centroid_threshold
                    score = iou + (1 - dist/centroid_threshold)*0.5;
                    if score > best_score
                        best_score = score;
                        best_a     = a;
                    end
                end
            end
            if best_a > 0
                matched_auto(best_a) = true;
                matched_man(m)       = true;
                all_iou(end+1)       = best_score;
            end
        end

        TP        = sum(matched_man);
        FP        = numAgg - sum(matched_auto);
        FN        = size(manual_boxes,1) - TP;
        precision = TP/(TP+FP+eps);
        recall    = TP/(TP+FN+eps);
        all_precision(end+1) = precision;
        all_recall(end+1)    = recall;

        fprintf('  Manual:%d Auto:%d | TP:%d FP:%d FN:%d | P:%.2f R:%.2f\n', ...
            size(manual_boxes,1), numAgg, TP, FP, FN, precision, recall);
    end

    % Final metrics for this method
    fprintf('\n FINAL METRICS: %s \n', methods{method_idx});
    fprintf('Mean Precision: %.3f\n', mean(all_precision));
    fprintf('Mean Recall:    %.3f\n', mean(all_recall));
    mean_f1 = mean(2*all_precision.*all_recall ./ (all_precision+all_recall+eps));
    fprintf('Mean F1:        %.3f\n', mean_f1);
    fprintf('Mean IoU:       %.3f\n', mean(all_iou));
    fprintf('Mean mv used:   %.1f (range: %.1f - %.1f)\n', ...
        mean(mv_values), min(mv_values), max(mv_values));

    % Pearson
    if length(manual_counts_all) >= 3
        [r_p, p_p] = corr(manual_counts_all', auto_counts_all', 'Type','Pearson');
        [r_s, p_s] = corr(manual_counts_all', auto_counts_all', 'Type','Spearman');
        fprintf('\nPearson  r=%.3f p=%.4f\n', r_p, p_p);
        fprintf('Spearman r=%.3f p=%.4f\n', r_s, p_s);
    end

    % Bland-Altman
    diff_counts = manual_counts_all - auto_counts_all;
    mean_counts = (manual_counts_all + auto_counts_all) / 2;
    mean_diff   = mean(diff_counts);
    sd_diff     = std(diff_counts);
    loa_upper   = mean_diff + 1.96*sd_diff;
    loa_lower   = mean_diff - 1.96*sd_diff;
    fprintf('\nBland-Altman Bias: %.2f | LoA: [%.2f, %.2f]\n', mean_diff, loa_lower, loa_upper);

    % Bland-Altman plot
    fig_ba = figure('Visible','off','Position',[100 100 800 600]);
    scatter(mean_counts, diff_counts, 80, 'b', 'filled');
    hold on;
    yline(mean_diff, 'r-',  sprintf('Bias=%.2f', mean_diff), 'LineWidth',2,'LabelHorizontalAlignment','left');
    yline(loa_upper, 'b--', sprintf('+1.96SD=%.2f', loa_upper), 'LineWidth',1.5,'LabelHorizontalAlignment','left');
    yline(loa_lower, 'b--', sprintf('-1.96SD=%.2f', loa_lower), 'LineWidth',1.5,'LabelHorizontalAlignment','left');
    yline(0, 'k:', 'Zero', 'LineWidth',1);
    xlabel('Mean of Manual and Auto Counts','FontSize',13);
    ylabel('Difference (Manual - Auto)','FontSize',13);
    title(sprintf('Bland-Altman: %s', methods{method_idx}),'FontSize',14);
    grid on;
    saveas(fig_ba, fullfile(method_folder, 'bland_altman.png'));
    close(fig_ba);

    % Scatter plot
    fig_sc = figure('Visible','off','Position',[100 100 700 600]);
    scatter(manual_counts_all, auto_counts_all, 80, 'r', 'filled');
    hold on;
    max_val = max([manual_counts_all, auto_counts_all]);
    plot([0 max_val],[0 max_val],'k--','LineWidth',1.5);
    xlabel('Manual Count','FontSize',13);
    ylabel('Automated Count','FontSize',13);
    title(sprintf('Manual vs Auto: %s\nPearson r=%.3f p=%.4f', methods{method_idx}, r_p, p_p),'FontSize',14);
    grid on;
    saveas(fig_sc, fullfile(method_folder, 'scatter_manual_vs_auto.png'));
    close(fig_sc);

    fprintf('Plots saved to: %s\n', method_folder);
end

fprintf('\n\nDONE. Compare the three method folders in: %s\n', out_folder);
fprintf('Pick the method with best F1 and highest Pearson r.\n');




%%
if isempty(gcp('nocreate'))
    parpool('local', 16);
end
%% SECTION 1: Initial Train/Val/Test Splitting
img_folder = "/home/srivarshans.sbb.iitmandi/Durba/original images";
imds = imageDatastore(img_folder);
oF = imds.Files;
v  = "/home/srivarshans.sbb.iitmandi/Durba/yolo_train_dataset/images/val";
test = "/home/srivarshans.sbb.iitmandi/Durba/Each_augmentation_folder/orig_test";
train = "/home/srivarshans.sbb.iitmandi/Durba/Each_augmentation_folder/orig_train";

if ~exist(v,  'dir'), mkdir(v);  end
if ~exist(test, 'dir'), mkdir(test); end
if ~exist(train,'dir'), mkdir(train);end

val_count   = 0;
test_count  = 0;
train_count = 0;

for j = 1:numel(oF)
    n=imread(oF{j});
    
    if mod(j, 9) == 0
        newName = sprintf("val_img%d.png", j);
        savePath = fullfile(v, newName);
        imwrite(n, savePath);
        val_count = val_count + 1;
    elseif mod(j, 9) == 1 && j > 1
        newName = sprintf("test_img%d.png", j);
        savePath = fullfile(test, newName);
        imwrite(n, savePath);
        test_count = test_count + 1;
    else
        newName = sprintf("train_img%d.png", j);
        savePath = fullfile(train, newName);
        imwrite(n, savePath);
        train_count = train_count + 1;
    end
    if mod(j, 1000) == 0
        fprintf("Processed %d / %d\n", j, numel(oF));
    end
end

fprintf("\nSplit complete.\n");
fprintf("Train : %d images (%.1f%%)\n", train_count, 100*train_count/numel(oF));
fprintf("Val   : %d images (%.1f%%)\n", val_count,   100*val_count/numel(oF));
fprintf("Test  : %d images (%.1f%%)\n", test_count,  100*test_count/numel(oF));
fprintf("Total : %d images\n", train_count + val_count + test_count);

%% SECTION 2: Sub-dividing Images into 4 Quadrants
img_folder="/home/srivarshans.sbb.iitmandi/Durba/Each_augmentation_folder/orig_train";
imds = imageDatastore(img_folder);
oF = imds.Files;
q="/home/srivarshans.sbb.iitmandi/Durba/Each_augmentation_folder/aug_imgs_4parts";
if ~exist(q,  'dir'), mkdir(q);  end
for j=1:numel(oF)
    [~, fname, ext] = fileparts(oF{j});
    n=imread(oF{j});
    d=(size(n));
    r=d(1);
    c=d(2);
   
    r_m=floor(r/2);
    c_m=floor(c/2);
    
    % ORIGINAL 
    copyfile(oF{j}, fullfile("/home/srivarshans.sbb.iitmandi/Durba/Each_augmentation_folder/aug_imgs_4parts", [fname ext]));
    
    % TOP-LEFT
    i_tl=n(1:r_m,1:c_m,:);
    name=sprintf("tl_img%d.png",j);
    file_path_2=fullfile("/home/srivarshans.sbb.iitmandi/Durba/Each_augmentation_folder/aug_imgs_4parts",name);
    imwrite(i_tl, file_path_2);
    
    % TOP-RIGHT
    i_tr=n(1:r_m,c_m+1:end,:);
    name=sprintf("tr_img%d.png",j);
    file_path_2=fullfile("/home/srivarshans.sbb.iitmandi/Durba/Each_augmentation_folder/aug_imgs_4parts",name);
    imwrite(i_tr, file_path_2);
    
    % BOTTOM-LEFT
    i_bl=n(r_m+1:end,1:c_m,:);
    name=sprintf("bl_img%d.png",j);
    file_path_2=fullfile("/home/srivarshans.sbb.iitmandi/Durba/Each_augmentation_folder/aug_imgs_4parts",name);
    imwrite(i_bl, file_path_2);
    
    % BOTTOM-RIGHT
    i_br=n(r_m+1:end,c_m+1:end,:);
    name=sprintf("br_img%d.png",j);
    file_path_2=fullfile("/home/srivarshans.sbb.iitmandi/Durba/Each_augmentation_folder/aug_imgs_4parts",name);
    imwrite(i_br, file_path_2);
end

%% SECTION 3: Multi-angle Rotations
img_folder = "/home/srivarshans.sbb.iitmandi/Durba/Each_augmentation_folder/aug_imgs_4parts";
imds = imageDatastore(img_folder);
oF = imds.Files;
angles = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160, 170, 180, 190, 200, 210, 220, 230, 240, 250, 260, 270, 280, 290, 300, 310, 320, 330, 340, 350];

q="/home/srivarshans.sbb.iitmandi/Durba/Each_augmentation_folder/aug_imgs_angles";
if ~exist(q,  'dir'), mkdir(q);  end
for j = 1:numel(oF)
    n = imread(oF{j});
    name = sprintf("orig_0°img%d.png", j);
    file_path = fullfile("/home/srivarshans.sbb.iitmandi/Durba/Each_augmentation_folder/aug_imgs_angles", name);
    imwrite(n, file_path);
end

% Rotate at all angles
for j = 1:numel(oF)
    n = imread(oF{j});
    for k = 1:numel(angles)
        ang = angles(k);
        rotated = imrotate(n, ang, 'crop');
        name = sprintf("%d°_img%d.png", ang, j);
        file_path = fullfile("/home/srivarshans.sbb.iitmandi/Durba/Each_augmentation_folder/aug_imgs_angles", name);
        imwrite(rotated, file_path);
    end
end
fprintf("Augmentation complete.\n");
fprintf("Total images: %d originals + %d rotated = %d total\n", numel(oF), numel(oF)*numel(angles), numel(oF)*(1 + numel(angles)));

%% SECTION 4: YOLO Training Label Generator & Segmentation Pipeline
clc; clear; close all;


img_folder   = "/home/srivarshans.sbb.iitmandi/Durba/yolo_train_dataset/images/aug_imgs_angles";
label_folder = "/home/srivarshans.sbb.iitmandi/Durba/yolo_train_dataset/labels/train";
all_lbl_dir  = "/home/srivarshans.sbb.iitmandi/Durba/All_labels";
all_img_dir  = "/home/srivarshans.sbb.iitmandi/Durba/All_images";
gt_img_dir   = "/home/srivarshans.sbb.iitmandi/Durba/Ground-truth";
train_img_dir= "/home/srivarshans.sbb.iitmandi/Durba/yolo_train_dataset/images/train";

% Create output folders if they don't exist
folders = {label_folder, all_lbl_dir, all_img_dir, gt_img_dir, train_img_dir};
for f = 1:numel(folders)
    if ~exist(folders{f}, 'dir'), mkdir(folders{f}); end
end


min_area_px = 100;    
max_area_px = 2981;   


imds = imageDatastore(img_folder);
oF   = imds.Files;
fprintf('Found %d images in: %s\n\n', numel(oF), img_folder);

total_detections = 0;
skipped_images   = 0;

for i = 1:numel(oF)
    img = imread(oF{i});
    R = img(:,:,1);
    G = img(:,:,2);
    B = img(:,:,3);
    imgHeight = size(img, 1);
    imgWidth  = size(img, 2);
    
    % Mean + 2SD Adaptive Threshold 
    G_flat = double(G(G > 30));          
    mv     = mean(G_flat) + 2 * std(G_flat);
    
    % Handling path parsing safely across platforms
    [~, explicit_name, ext_type] = fileparts(oF{i});
    fprintf('[%d/%d] %s%s | mv = %.1f\n', i, numel(oF), explicit_name, ext_type, mv);
    
    %  Green-channel colour mask 
    BW = R < mv & G > mv & B < mv;
    BW = bwareaopen(BW, 50);            
    
    % Watershed 
    D  = -bwdist(~BW);                  
    D  = imhmin(D, 2);                  
    L  = watershed(D);
    BW = BW & (L > 0);                  
    
    %  Connected components & area filter 
    CC    = bwconncomp(BW);
    stats = regionprops(CC, 'BoundingBox', 'Area');
    if isempty(stats)
        fprintf('  → No detections. Skipping label file.\n');
        skipped_images = skipped_images + 1;
        imwrite(img, fullfile(all_img_dir,   strcat(explicit_name, '.png')));
        imwrite(img, fullfile(train_img_dir, strcat(explicit_name, '.png')));
        continue;
    end
    
    keep  = [stats.Area] >= min_area_px & [stats.Area] <= max_area_px;
    stats = stats(keep);
    CC.PixelIdxList = CC.PixelIdxList(keep);
    numObjects = sum(keep);
    total_detections = total_detections + numObjects;
    fprintf('  → %d objects detected after area filter\n', numObjects);
    
    %  Annotated image 
    img_annot = img;
    for m = 1:numObjects
        bb        = stats(m).BoundingBox;
        img_annot = insertShape(img_annot, 'Rectangle', bb, ...
                                'Color', 'white', 'LineWidth', 2);
    end
    
    %  Write YOLO labels 
    labelFile    = fullfile(label_folder, strcat(explicit_name, '.txt'));
    allLabelPath = fullfile(all_lbl_dir,  strcat(explicit_name, '.txt'));
    fid     = fopen(labelFile,    'w');
    fid_all = fopen(allLabelPath, 'w');
    
    for m = 1:numObjects
        pixels   = CC.PixelIdxList{m};
        [py, px] = ind2sub([imgHeight, imgWidth], pixels);
        x_center = mean(px) / imgWidth;
        y_center = mean(py) / imgHeight;
        width    = (max(px) - min(px)) / imgWidth;
        height   = (max(py) - min(py)) / imgHeight;
        
        fprintf(fid,     '0 %.6f %.6f %.6f %.6f\n', x_center, y_center, width, height);
        fprintf(fid_all, '0 %.6f %.6f %.6f %.6f\n', x_center, y_center, width, height);
    end
    fclose(fid);
    fclose(fid_all);
    
    %  Save images 
    imwrite(img,       fullfile(all_img_dir,   strcat(explicit_name, '.png')));
    imwrite(img,       fullfile(train_img_dir, strcat(explicit_name, '.png')));
    imwrite(img_annot, fullfile(gt_img_dir,    strcat(explicit_name, '.png')));
end

fprintf('Images processed : %d\n', numel(oF));
fprintf('Images skipped   : %d  (no detections)\n', skipped_images);
fprintf('Total detections : %d\n', total_detections);
fprintf('Labels saved to  : %s\n', label_folder);
fprintf('GT images saved  : %s\n', gt_img_dir);

%% SECTION 5: Gamma Visual Test (Note: Cluster instances might need VNC/Display for plotting)
% clc; clear; close all;
% imgFolder = "/home/srivarshans.sbb.iitmandi/Durba/Each_augmentation_folder/orig_train";
% imds      = imageDatastore(imgFolder);
% 
% testIdx   = [1, 2, 3, 4, 5, 6];
% gammas       = [0.3, 0.4, 0.5, 0.7, 1.0, 1.5, 2.0, 3.0];
% gammaLabels  = {"g=0.3","g=0.4","g=0.5","g=0.7","orig","g=1.5","g=2.0","g=3.0"};
% 
% figure('Position', [0 0 1600 900]);
% plotIdx = 1;
% for ti = 1:numel(testIdx)
%     img        = imread(imds.Files{testIdx(ti)});
%     img_single = im2single(img);
%     for gi = 1:numel(gammas)
%         result = im2uint8(img_single .^ gammas(gi));
%         subplot(numel(testIdx), numel(gammas), plotIdx);
%         imshow(result);
%         if ti == 1
%             title(gammaLabels{gi}, 'FontSize', 8);
%         end
%         plotIdx = plotIdx + 1;
%     end
% end
% sgtitle('Gamma Range Test — rows=images, cols=gamma values');



%% SECTION 7: Parallel Label Generation of Gray-scale and Gamma Images
imgFolder       = "/home/srivarshans.sbb.iitmandi/Durba/Each_augmentation_folder/aug_imgs_angles";
labelFolder     = "/home/srivarshans.sbb.iitmandi/Durba/All_labels";
allImagesFolder = "/home/srivarshans.sbb.iitmandi/Durba/All_images";
intensityFolder = "/home/srivarshans.sbb.iitmandi/Durba/Each_augmentation_folder/Intensity_Images";
grayFolder      = "/home/srivarshans.sbb.iitmandi/Durba/Each_augmentation_folder/gray_Images";
gtFolder        = "/home/srivarshans.sbb.iitmandi/Durba/Ground-truth";
noisyFolder     = "/home/srivarshans.sbb.iitmandi/Durba/Each_augmentation_folder/noisy_images";
yoloImgFolder   = "/home/srivarshans.sbb.iitmandi/Durba/yolo_train_dataset/images/train";
yoloLblFolder   = "/home/srivarshans.sbb.iitmandi/Durba/yolo_train_dataset/labels/train";

folders = [allImagesFolder, intensityFolder, grayFolder, gtFolder, noisyFolder, yoloImgFolder, yoloLblFolder];
for f = folders
    if ~exist(f, 'dir'), mkdir(f); end
end

imds = imageDatastore(imgFolder);
files = imds.Files;
N = numel(files);
fprintf('Total images: %d\n', N);

allData = cell(N,1);
validMask = false(N,1);

for i = 1:N
    [~, baseName, ~] = fileparts(files{i});
    lp = fullfile(labelFolder, baseName + ".txt");
    if exist(lp,'file')
        allData{i} = readmatrix(lp);
        validMask(i) = true;
    end
end

validIdx = find(validMask);
fprintf('Valid images: %d\n', numel(validIdx));

gamma_values = [1.5, 0.7];
gamma_names  = ["g1", "g2"];



fprintf('Starting fast parallel processing...\n');

parfor idx = 1:numel(validIdx)
    i        = validIdx(idx);
    img      = imread(files{i});
    img_single = im2single(img);
    data     = allData{i};
    [h,w,~]  = size(img);

    if ~isempty(data)
        boxes  = data(:,2:5);
        pBoxes = zeros(size(boxes));
        for b = 1:size(boxes,1)
            xc = boxes(b,1)*w; yc = boxes(b,2)*h;
            bw = boxes(b,3)*w; bh = boxes(b,4)*h;
            pBoxes(b,:) = [xc-bw/2, yc-bh/2, bw, bh];
        end
    else
        pBoxes = [];
    end

    % Gamma variations mapping
    for k = 1:numel(gamma_values)
        img_out = im2uint8(img_single .^ gamma_values(k));
        if ~isempty(pBoxes)
            img_gt = insertShape(img_out, 'Rectangle', pBoxes, ...
                'Color', 'white', 'LineWidth', 2);
        else
            img_gt = img_out;
        end
        newBase  = sprintf("%s_img%d", gamma_names(k), i);
        lblPath  = fullfile(labelFolder, newBase + ".txt");
        imwrite(img_out, fullfile(allImagesFolder, newBase + ".png"));
        imwrite(img_out, fullfile(intensityFolder, newBase + ".png"));
        imwrite(img_gt,  fullfile(gtFolder,        newBase + ".png"));
        imwrite(img_out, fullfile(yoloImgFolder, newBase + ".png"));
        
        fid = fopen(lblPath, 'w');
        for r = 1:size(data, 1)
            fprintf(fid, '%d %.6f %.6f %.6f %.6f\n', ...
                int32(data(r,1)), data(r,2), data(r,3), data(r,4), data(r,5));
        end
        fclose(fid);
        
        yoloLblPath = fullfile(yoloLblFolder, newBase + ".txt");
        fid = fopen(yoloLblPath, 'w');
        for r = 1:size(data, 1)
            fprintf(fid, '%d %.6f %.6f %.6f %.6f\n', ...
                int32(data(r,1)), data(r,2), data(r,3), data(r,4), data(r,5));
        end
        fclose(fid);
    end
    
    % Grayscale mapping
    grayImg = rgb2gray(img);
    if ~isempty(pBoxes)
        grayGT = insertShape(grayImg, 'Rectangle', pBoxes, ...
            'Color', 'white', 'LineWidth', 2);
    else
        grayGT = grayImg;
    end
    newBase  = sprintf("gray_img%d", i);
    lblPath  = fullfile(labelFolder, newBase + ".txt");
    imwrite(grayImg, fullfile(allImagesFolder, newBase + ".png"));
    imwrite(grayImg, fullfile(grayFolder,      newBase + ".png"));
    imwrite(grayGT,  fullfile(gtFolder,        newBase + ".png"));
    imwrite(grayImg, fullfile(yoloImgFolder, newBase + ".png"));
    
    fid = fopen(lblPath, 'w');
    for r = 1:size(data, 1)
        fprintf(fid, '%d %.6f %.6f %.6f %.6f\n', ...
            int32(data(r,1)), data(r,2), data(r,3), data(r,4), data(r,5));
    end
    fclose(fid);
    
    yoloLblPath = fullfile(yoloLblFolder, newBase + ".txt");
    fid = fopen(yoloLblPath, 'w');
    for r = 1:size(data, 1)
        fprintf(fid, '%d %.6f %.6f %.6f %.6f\n', ...
            int32(data(r,1)), data(r,2), data(r,3), data(r,4), data(r,5));
    end
    fclose(fid);
end

fprintf('ALL AUGMENTATIONS COMPLETE.\n');

 %% SECTION 8: Noise Augmentation Block
allImagesFolder = "/home/srivarshans.sbb.iitmandi/Durba/All_images";
labelFolder     = "/home/srivarshans.sbb.iitmandi/Durba/All_labels";
noisyFolder     = "/home/srivarshans.sbb.iitmandi/Durba/Each_augmentation_folder/noisy_images";
gtFolder        = "/home/srivarshans.sbb.iitmandi/Durba/Ground-truth";
yoloImgFolder   = "/home/srivarshans.sbb.iitmandi/Durba/yolo_train_dataset/images/train";
yoloLblFolder   = "/home/srivarshans.sbb.iitmandi/Durba/yolo_train_dataset/labels/train";

folders = [noisyFolder, gtFolder, yoloImgFolder, yoloLblFolder];
for f = folders
    if ~exist(f, 'dir'), mkdir(f); end
end

imds = imageDatastore(allImagesFolder);
files = imds.Files;
N = numel(files);
fprintf('Total images in final dataset: %d\n', N);

noise_fraction = 0.15;
noise_variance = 0.025;
rng(42); 
numToNoise = round(noise_fraction * N);
noiseIdx   = randperm(N, numToNoise);
noiseMask = false(N,1);
noiseMask(noiseIdx) = true;

fprintf('Applying noise to %d images (%.2f%%)\n', numToNoise, noise_fraction*100);
if isempty(gcp('nocreate'))
    parpool('local', 6);
end

fprintf('Starting noise augmentation...\n');
parfor i = 1:N
    if ~noiseMask(i)
        continue;
    end
    
    img = imread(files{i});
    img_single = im2single(img);
    [~, baseName, ~] = fileparts(files{i});
    labelPath = fullfile(labelFolder, baseName + ".txt");
    
    if exist(labelPath, 'file')
        data = readmatrix(labelPath);
    else
        data = [];
    end
    [h, w, ~] = size(img);
  
    if ~isempty(data)
        boxes = data(:,2:5);
        pBoxes = zeros(size(boxes));
        for b = 1:size(boxes,1)
            xc = boxes(b,1)*w; yc = boxes(b,2)*h;
            bw = boxes(b,3)*w; bh = boxes(b,4)*h;
            pBoxes(b,:) = [xc-bw/2, yc-bh/2, bw, bh];
        end
    else
        pBoxes = [];
    end
    
    noise  = randn(size(img_single), 'single') * sqrt(noise_variance);
    noisy  = img_single + noise;
    noisy  = min(max(noisy, 0), 1);
    noisyImg = im2uint8(noisy);
    
    if ~isempty(pBoxes)
        noisyGT = insertShape(noisyImg, 'Rectangle', pBoxes, ...
            'Color', 'white', 'LineWidth', 2);
    else
        noisyGT = noisyImg;
    end
    
    newBase = "noisy_" + baseName;
    
    imwrite(noisyImg, fullfile(noisyFolder,   newBase + ".png"));
    imwrite(noisyGT,  fullfile(gtFolder,      newBase + ".png"));
    imwrite(noisyImg, fullfile(yoloImgFolder, newBase + ".png"));
    imwrite(noisyImg, fullfile(allImagesFolder, newBase + ".png"));
    
    % Save updated labels to regular label directory
    fid = fopen(fullfile(labelFolder, newBase + ".txt"), 'w');
    for r = 1:size(data,1)
        fprintf(fid, '%d %.6f %.6f %.6f %.6f\n', ...
            int32(data(r,1)), data(r,2), data(r,3), data(r,4), data(r,5));
    end
    fclose(fid);
    
    % Save updated labels to YOLO label directory
    fid = fopen(fullfile(yoloLblFolder, newBase + ".txt"), 'w');
    for r = 1:size(data,1)
        fprintf(fid, '%d %.6f %.6f %.6f %.6f\n', ...
            int32(data(r,1)), data(r,2), data(r,3), data(r,4), data(r,5));
    end
    fclose(fid);
end
fprintf('Noise augmentation complete.\n');
%%
