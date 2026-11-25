%% Manual YOLO Label Generation for Validation Set
% Run this on your LOCAL machine (needs display for getrect)
% Output: one .txt per image in YOLO format: 0 x_center y_center width height

val_img_folder  = "D:\val";
val_lbl_folder  = "D:\Count My Proteins\yolo_train_dataset\labels\val";

if ~exist(val_lbl_folder, 'dir'), mkdir(val_lbl_folder); end

imds = imageDatastore(val_img_folder);
oF   = imds.Files;

fprintf('Found %d validation images.\n', numel(oF));
fprintf('Instructions: Draw boxes with getrect, CLOSE figure when done with each image.\n\n');

for i = 1:numel(oF)
    img = imread(oF{i});
    [~, imgName, ~] = fileparts(oF{i});
    imgHeight = size(img, 1);
    imgWidth  = size(img, 2);

    fprintf('[%d/%d] %s — Draw boxes, CLOSE figure when done\n', i, numel(oF), imgName);

    fig = figure('Name', sprintf('%s — CLOSE when done', imgName));
    imshow(img); hold on;
    title(sprintf('%s | Draw boxes | CLOSE figure when done', imgName), 'Color', 'w');
    set(gcf, 'Color', 'k');

    boxes = [];
    while ishandle(fig)
        try
            pos = getrect(fig);          % [x y width height] in pixels
            if ~ishandle(fig), break; end
            if pos(3) < 2 || pos(4) < 2, continue; end
            boxes(end+1, :) = pos;
            rectangle('Position', pos, 'EdgeColor', 'y', 'LineWidth', 1.5);
            fprintf('  Box %d: x=%.1f y=%.1f w=%.1f h=%.1f\n', ...
                size(boxes,1), pos(1), pos(2), pos(3), pos(4));
        catch
            break;
        end
    end

    % Write YOLO format label file
    lblPath = fullfile(val_lbl_folder, [char(imgName), '.txt']);
    fid = fopen(lblPath, 'w');
    for b = 1:size(boxes, 1)
        x      = boxes(b, 1);
        y      = boxes(b, 2);
        bw     = boxes(b, 3);
        bh     = boxes(b, 4);
        % Convert pixel [x y w h] top-left to YOLO normalised center format
        x_center = (x + bw/2) / imgWidth;
        y_center = (y + bh/2) / imgHeight;
        width    = bw / imgWidth;
        height   = bh / imgHeight;
        fprintf(fid, '0 %.6f %.6f %.6f %.6f\n', x_center, y_center, width, height);
    end
    fclose(fid);

    fprintf('  Saved %d boxes to %s.txt\n\n', size(boxes,1), imgName);
end

fprintf('=== ALL VALIDATION IMAGES LABELLED ===\n');
fprintf('Labels saved to: %s\n', val_lbl_folder);
