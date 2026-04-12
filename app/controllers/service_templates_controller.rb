class ServiceTemplatesController < ApplicationController
  before_action :set_service_template, only: %i[show edit update destroy]

  def index
    @service_templates = current_user.service_templates.order(:name)
  end

  def show
    respond_to do |format|
      format.html { redirect_to edit_service_template_path(@service_template) }
      format.json { render json: service_template_json(@service_template) }
    end
  end

  def new
    @service_template = current_user.service_templates.build
  end

  def create
    @service_template = current_user.service_templates.build(service_template_params)
    if @service_template.save
      redirect_to service_templates_path, notice: "Plantilla creada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @service_template.update(service_template_params)
      redirect_to service_templates_path, notice: "Plantilla actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @service_template.destroy!
    redirect_to service_templates_path, notice: "Plantilla eliminada."
  end

  private

  def set_service_template
    @service_template = current_user.service_templates.find(params[:id])
  end

  def service_template_params
    params.require(:service_template).permit(
      :name, :billing_period, :default_description, :default_base_imponible, :default_iva_rate
    )
  end

  def service_template_json(t)
    {
      id: t.id,
      name: t.name,
      billing_period: t.billing_period,
      default_description: t.default_description,
      default_base_imponible: t.default_base_imponible&.to_s("F"),
      default_iva_rate: t.default_iva_rate&.to_s("F")
    }
  end
end
