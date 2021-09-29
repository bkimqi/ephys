classdef ThetaPeakCombined
    %THETAPEAKCOMBINED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        thpkList
        Info
    end
    
    methods
        function obj = ThetaPeakCombined(thpk)
            %THETAPEAKCOMBINED Construct an instance of this class
            %   Detailed explanation goes here
            obj.thpkList=CellArrayList();
            try
                obj.thpkList.add(thpk);
            catch
            end
        end
        
        function obj = plus(obj,thpk)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            obj.thpkList.add(thpk);
        end
        function obj = add(obj,thpk,num)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            obj.thpkList.add(thpk,num);
        end
        function newthpks = merge(obj,thpks)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            newthpks=experiment.plot.thetaPeak.ThetaPeakCombined;
            if isa(thpks,'experiment.plot.thetaPeak.ThetaPeakCombined')
                for il=1:max(obj.thpkList.length,thpks.thpkList.length)
                    thpk1=obj.thpkList.get(il);
                    thpk2=thpks.thpkList.get(il);
                    try
                        thpkmsum=thpk1.merge(thpk2);
                    catch
                        thpkmsum=thpk2.merge(thpk1);
                    end
                    newthpks=newthpks.add(thpkmsum,il);
                end
            else
                newthpks=obj;
            end
%             try close(7);catch, end; figure(7);obj.plotCF
%             try close(8);catch, end;figure(8);thpks.plotCF
%             try close(9);catch, end;figure(9);newthpks.plotCF
        end
        function axsr=plotCF(obj,rows,row,col)
            if ~exist('rows','var')
                rows=1; 
            else
                if isa(rows,'matlab.graphics.axis.Axes');
                    axs=rows;
                end
            end
            
            if ~exist('row','var')
                row=1;
            end
            list=obj.thpkList;
            for isub=1:list.length
                if exist('axs','var')
                    ax=axes(axs(isub)); %#ok<LAXES>
                    hold on
                else
                    if exist('col','var')
                        subplot(rows, col, (row-1)*col+ isub)
                    else
                        subplot(rows, list.length, (row-1)*list.length + isub)
                    end
                end
                thesub=list.get(isub);
                if ~isempty(thesub.Signal)
                    thesub.plotCF
                end
                if isub>1
                    xlabel('');
                    xticks('')
%                     xticks([]);
                else
                    text(ax.x, obj.Info.Session.toString);
                end
                if row<rows
                    ylabel('');
                end
                yticks([]);
                axsr(isub)=gca;
            end            
        end
        function axsr=plotPW(obj,rows,row,col)
            if ~exist('rows','var')
                rows=1; 
            else
                if isa(rows,'matlab.graphics.axis.Axes');
                    axs=rows;
                end
            end
            
            if ~exist('row','var')
                row=1;
            end
            list=obj.thpkList;
            for isub=1:list.length
                if exist('axs','var')
                    axes(axs(isub)); %#ok<LAXES>
                    hold on
                else
                    if exist('col','var')
                        subplot(rows, col, (row-1)*col+ isub)
                    else
                        subplot(rows, list.length, (row-1)*list.length + isub)
                    end
                end
                thesub=list.get(isub);
                if ~isempty(thesub.Signal)
                    thesub.plotPW
                end
                if isub>1
                    xlabel('');
                    xticks('')
%                     xticks([]);
                end
                if row<rows
                    ylabel('');
                end
                yticks([]);
                axsr(isub)=gca;
            end
        end
    end
end

